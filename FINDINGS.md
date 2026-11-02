# Findings — Wordbook-rb

Defects and environment limits found while porting Wordbook to Ruby GTK4. Each
one is a reason some gap is **hard**. None of them is a reason a gap is closed,
and none of them belongs in the sentence that describes a gap: that sentence
lives next to the code, names the behaviour the user does not get, and points
here.

| | |
|---|---|
| Port | `ruby` |
| Bindings | `gtk4` 4.3.9, `adwaita` 4.3.9 (ruby-gnome) |
| Runtime | GTK 4.22.4, Ruby 3.4.9, Xvfb through the dev shell |

Four of the thirteen below are **closed**, and three of those four were never
really open: 1, 2 and 3 each recorded a widget as unconstructible when the
constructor only wanted its arguments positionally, and 5 recorded GTK as
uninitialisable when the dev shell's banner names the way in. They are kept,
marked closed in their headings, because the shape of the mistake is worth
having written down: an `ArgumentError` from these bindings advertises a
keyword signature whatever the constructor actually wants, and a defect that
excuses missing behaviour deserves to be re-run before it is believed.

## 1 — `Adwaita::Application` takes its arguments positionally — **closed**

This was recorded as "cannot be constructed". It can:
`Adwaita::Application.new("dev.mufeed.Wordbook", :handles_command_line)`
works. What fails is every keyword form — `new`, `new(application_id: …)` —
and the error message advertises the signature as keywords, which is what the
earlier round read it as. The rule from the skill holds: when a constructor
fails, try positional arguments in the order the message names them.

The port's application is an `Adwaita::Application`
(`lib/wordbook/application.rb`), as upstream's is (`wordbook/main.py:20`).

## 2 — `Adwaita::ApplicationWindow` and `Adwaita::Breakpoint` — **closed**

Also recorded as unconstructible, and also only unconstructible from keywords.
`Adwaita::ApplicationWindow.new(app)` works; so does
`Adwaita::Breakpoint.new(Adwaita::BreakpointCondition.parse("max-width: 550sp"))`
with `add_setter(widget, "collapsed", true)` and
`window.add_breakpoint(breakpoint)`.

So the window is an `Adwaita::ApplicationWindow` carrying the breakpoint
upstream declares on its template (`window.blp:54`), and the hand-rolled
`update_collapse` that watched `notify::default-width` is gone. The content
goes in through `content=` rather than `child=`. `test/drive_wordbook.rb`
resizes the window and watches the split view collapse at 420px and open again,
so this is measured rather than reasoned.

Two readers to know: the reader for `collapsed` is `collapsed?`, not
`collapsed`, and `Adwaita::WrapBox` has no `homogeneous=`.

## 3 — `Adwaita::ShortcutsItem` takes positional arguments — **closed**

`Adwaita::ShortcutsItem.new` rejects every keyword form and rejects a nil
accelerator; `new(title, "")` works. The second half of the earlier finding —
"there is no way through the binding to set `action-name`" — was wrong:
`item.action_name = "win.preferences"` works, and Adwaita then resolves the
accelerator from what the application bound.

So the dialog's rows name their action, as upstream's do
(`shortcuts-dialog.blp`), and the port no longer hands them accelerator
strings out of `Application::APP_ACCELS`.
`tmp/shots/16-shortcuts.png`, written by `test/drive_wordbook.rb`, shows the
eight rows with their keys filled in.

Still true: upstream never registers `app.shortcuts`, because libadwaita
auto-loads `shortcuts-dialog.ui` from the resource base path
(`set_resource_base_path(RES_PATH)`, `main.py:80`). The port has no gresource
bundle, so it installs the action and presents the dialog itself, and it binds
`<Primary>question` to it, which upstream binds to nothing.

## 4 — Ruby has no zstd, and the port shells out to the program

Upstream decompresses the bundled WordNet archive with Python's `zstd`
module. There is no zstd in Ruby's standard library and no zstd gem in this
checkout's bundle, so `lib/wordbook/database_manager.rb` pipes the archive
through the `zstd` program.

What the user loses: on a machine with the archive installed but without the
`zstd` program, this port says "Database not found — Installation is
incomplete. Please reinstall Wordbook." about a complete installation.
Upstream works there.

Closing it needs a zstd binding (`ruby-zstds`, `zstd-ruby`) added as a
dependency, or the decompressor vendored. Neither was done this round.

## 5 — GTK runs headlessly through the dev shell's Xvfb — **closed**

An earlier round recorded that `require "gtk4"` raised `Gtk::InitError` here
and concluded that nothing could be rendered. The dev shell's banner names the
way in: every ruby invocation goes through

    nix develop --command xvfb-run -a ruby <script>

and GTK initialises, the window maps, and `Gsk::Renderer#render_texture` plus
`Gdk::Texture#save_to_png` write a PNG of it. `test/drive_wordbook.rb` is the
driver; `tmp/shots` is where its nineteen PNGs land.

What that cost while it was believed: the first time this port was presented
it aborted during startup, on the accessible labels, which had been written
from the typelib and never run (defect 10). The source had read as correct for
a whole round.

Still true: the two specs that require `gtk4` are not the reason the suite does
not run here. `spec/spec_helper.rb` requires `kettle/test/rspec`, which is not
in this checkout's bundle and cannot be fetched offline, so no example runs at
all. See `TEST_PARITY.md`.

## 6 — `sqlite3` was missing from the packaged app's bundle — **closed**

For two rounds the app built by `nix build` raised
`LoadError: cannot load such file -- sqlite3` the first time a search reached
the database, because `nix/gemset.nix` held 35 gems and `sqlite3` was not among
them: `flake.nix` put `pkgs.rubyPackages_3_4.sqlite3` in the devShell only, so
every check passed against a tree that had the gem and the only installable
artifact did not.

Closed: `cd nix && bundle lock && bundix` on a networked machine.
`gem "sqlite3", force_ruby_platform: true` in `nix/Gemfile` — the platform
flag matters, because the precompiled `-x86_64-linux-gnu` gem drops the `ruby`
platform out of the lockfile and carries its own libsqlite3; with it, bundlerEnv
builds the C extension against nixpkgs' sqlite. Verified against the built
wrapper: it opens a database and reads a row.

So that it cannot regress: `checks.packaged-database-read` in `flake.nix` runs
the **packaged** ruby, with the same `-rbundler/setup` and `BUNDLE_WITHOUT` the
installed launcher's wrapper uses, over a WordNet-shaped SQLite file.
`nix flake check` runs it.

## 7 — the port ships no WordNet archive — **closed**

Upstream generates `wn-<version>.db.zst` at build time with
`scripts/generate-wn-db.py` and the Python `wn` package, and installs it into
`pkgdatadir`. The port reads that file's SQLite schema directly
(`lib/wordbook/base.rb:159`) but builds no archive and ships none, so unless
upstream Wordbook is installed alongside it, every search lands on the
"Database not found" page.

Generating it needed the `wn` package, which is Python, so a Ruby
`generate-wn-db.py` had to read Open English WordNet's XML and write `wn`'s
schema itself. That is what it now does: `lib/wordbook/lmf_reader.rb` streams
the WN-LMF lexicon and `lib/wordbook/database_builder.rb` writes the schema
`lib/wordbook/base.rb` reads, through `exe/wordbook-generate-db` and
`rake wn:db`. Verified against the real 2025 lexicon — 161,875 entries,
212,659 senses, 120,564 synsets — and read back with `Base::Wordnet`, which is
what `spec/wordbook/database_builder_spec.rb` does on a small lexicon on every
run.

What is still true, and is not a defect: the tree holds no archive. It is a
60 MB build product, and upstream does not commit one either — `install_wn_db`
is a meson option, off by default. `rake install:data` and `nix build` install
`data/wn-*.db.zst` into `share/wordbook` when a `rake wn:db` run has produced
one, and the app without one shows the page it is meant to.

## 8 — `Gio::DBusNodeInfo#interfaces` returns unusable values

Walking `Gio::DBusNodeInfo.new(xml).interfaces` yields values that cannot be
passed to `register_object`; `lookup_interface(name)` returns a usable
`Gio::DBusInterfaceInfo`. The search provider uses the latter
(`lib/wordbook/shell_search_provider.rb:101`).

## 9 — `GLib::Variant.new` cannot build `a{sv}` or a reply tuple

`GLib::Variant.new` raises `NotImplementedError` for `a{sv}`, which is the
type of every result meta the shell asks for, and cannot build the tuple a
D-Bus reply has to be wrapped in. The provider builds both by generating
GVariant text and parsing it with `GLib::Variant.parse`
(`lib/wordbook/shell_search_provider.rb:220-236`). Strings are escaped C-style
on the way in.

## 10 — `Gtk::Accessible#update_property` is unimplemented in the bindings

Upstream's `accessibility { label: … }` blocks are
`gtk_accessible_update_property_value(self, n, properties[], values[])`.
Introspection exposes it as `update_property(properties, values)`, and calling
it raises

    NotImplementedError: TODO: in Ruby -> GIArgument(array/C)[interface(enum)]

because ruby-gnome cannot marshal a C array of enum values. There is no
single-property variant, `update_relation` has the same shape, and the native
pointer a Fiddle call would need is not exposed on `GLib::Object`.

The way through is the one blueprint itself compiles those blocks into:
`Gtk::Builder` parses `<accessibility><property name="label">…</property>`.
`Utils.accessible(class_name, label)` builds a bare widget of the named class
from a one-object snippet and hands it back for the caller to configure in
Ruby, so the five icon-only buttons keep the labels upstream gives them. The
builder is kept alive alongside, because it owns what it built until the widget
is parented.

## 11 — the clipboard handlers rescued the wrong error class, and an empty selection killed the app — **fixed**

Upstream catches `GLib.Error` around `read_text_finish`
(`wordbook/window.py:242,260`), which in PyGObject is the one class every
GError arrives as. These bindings split GErrors by domain instead:

    Gdk::Clipboard#read_text_finish  ->  Gio::IOError::NotFound
    ancestors: Gio::IOError::NotFound < GLib::ErrorInfo < Gio::IOError
               < Gio::Error < StandardError

`Gio::Error` does **not** descend from `GLib::Error`, so the port's literal
translation of `except GLib.Error` caught nothing. `read_primary_selection`
runs on every `changed` of the primary selection, and an empty selection
raised straight out of the signal handler and ended the process — the whole
application, from an action no user takes deliberately.

Found by running the app: `test/drive_wordbook.rb` died silently part-way
through its run with no output, and the same sequence outside the harness
printed the GI backtrace. Nothing in the source reads as wrong, and a round of
static review had passed over it.

Fixed in `lib/wordbook/window.rb`: both handlers now rescue
`GLib::Error, Gio::Error`. `test/drive_wordbook.rb` emits the clipboard's own
`changed` signal with an empty selection and then checks the window is still
there.

## 12 — `Gtk::Widget#activate_action` activates nothing in these bindings

`win.activate_action("win.toggle-sidebar", nil)` returns the widget and has no
effect: the sidebar does not move, the menu does not open, the dialog does not
appear. The accelerator and menu-item paths inside GTK are fine — the action
exists, `window.lookup_action("toggle-sidebar").activate(nil)` does the work,
and the shortcuts dialog resolves every accelerator the application bound —
but the muxer entry point is not usable from Ruby.

What that cost: the previous driver, `test/drive_window.rb`, checked seven
window actions by calling `activate_action` and asserting it did not raise. It
never raised and it never activated anything, so seven green checks covered
nothing. `test/drive_wordbook.rb` activates the `Gio::SimpleAction` the window
registered instead, and checks what the action changed.

## 13 — the dev shell had no sqlite3, no espeak-ng and no zstd

Three of the port's runtime dependencies were missing from `devShells.default`,
so the database, the pronunciations and the archive extraction were code no run
could enter: every drive ended on the "Database not found" page. Added to
`flake.nix`: `pkgs.rubyPackages_3_4.sqlite3`, `pkgs.espeak-ng` and `pkgs.zstd`.

Defect 6 was unchanged by this and is closed separately: the devShell entry is
what `ruby exe/wordbook` in the shell uses, and `nix/gemset.nix` now carries
the gem for the packaged app.

## 14 — bundlerEnv's `groups` does not write `BUNDLE_WITHOUT`, and the packaged app died before `require`

Found by the check written for defect 6, which is the point of writing checks
over the artifact. `flake.nix` builds the app's gem closure with
`groups = [ "default" ]`, to keep rspec out of it, and bundlerEnv honours that
when it installs the gems — but it still writes the **whole** `Gemfile` and
`Gemfile.lock` beside them. `-rbundler/setup` in the launcher's wrapper then
resolves every group in that lockfile, cannot find rspec, and raises
`Bundler::GemNotFound` before `require "wordbook"` runs.

It was invisible because any environment with a `BUNDLE_*` variable already set
— a direnv-managed shell, for instance — resolves differently. `env -i
$out/bin/wordbook --info` is what shows it.

Closed: the launcher's wrapper passes `--set BUNDLE_WITHOUT test`, which is the
half of `groups` that bundlerEnv does not write for you.

## 15 — `Gtk::Widget#activate` does nothing on a `Gtk::ToggleButton`

Related to defect 12 and worse, because it fails silently in both directions.
On a plain `Gtk::Button`, `button.activate` emits `clicked` and runs the
handler. On a `Gtk::ToggleButton` carrying an `action-name` it returns the
widget and does nothing at all: `active?` does not change and the action is not
activated. Measured with a three-widget script — a `Gtk::ToggleButton` with
`action_name = "win.toggle-favorites"` and a `Gio::SimpleAction` counting its
activations:

```
[:before,          false, 0]
[:after_activate,  false, 0]   # Gtk::Widget#activate
[:after_emit_clicked, false, 1]   # signal_emit("clicked")
```

`signal_emit("clicked")` is the working path, and it is also the honest one:
`clicked` is what `GtkGestureClick` emits, so it exercises exactly the chain a
real click takes — through `GtkActionHelper` to the window's action. Note that
`active?` stays `false` after it: GTK suppresses the toggle button's own
internal flip when the widget is actionable, so the action's handler owns
`active`, which is how upstream's `_toggle_favorites_filter` is written
(`window.py:855-861`).

`test/drive_wordbook.rb` drives the favourites filter from both ends with it.

## 16 — the `gettext` gem's Rake task destroys a flat `po/<locale>.po` layout

`GetText::Tools::Task` assumes `po/<locale>/<domain>.po`. Upstream Wordbook —
like every meson/`i18n` project — ships the flat `po/<locale>.po`. Given the
flat layout, `rake gettext:mo:update` does not fail and does not warn: it
*creates* `po/de/wordbook.po` from the template with every msgstr empty, and
compiles that over `locale/de/LC_MESSAGES/wordbook.mo`. Measured: the catalogue
went from 3948 bytes / 53 msgids to 352 bytes / 0 msgids, in all fifteen
languages, exit status zero.

Worse, `lib/wordbook/translations.rb` named that command as the thing that
builds the catalogues, so following the port's own instructions emptied them.

Closed: `FlatLayoutTask` in the `Rakefile` subclasses the gem's task and
overrides its private `create_path` to return a `Path` whose `po_file`,
`po_time_stamp_file` and `edit_po_file` are flat. `rake gettext:mo:update` is
safe again (verified with `msgunfmt`), and `rake locale` — plain GNU `msgfmt`
over `po/<lang>.po` — is what `bin/setup` and the dev shell call.
