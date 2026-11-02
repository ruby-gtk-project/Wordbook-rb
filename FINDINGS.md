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

Four of the ten below are **closed**, and three of those four were never
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
goes in through `content=` rather than `child=`. `test/drive_window.rb`
resizes the window and watches the split view collapse at 420px and open again
at 900px, so this is measured rather than reasoned.

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
`tmp/screenshots/shortcuts.png`, written by `test/drive_window.rb`, shows the
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
`Gdk::Texture#save_to_png` write a PNG of it. `test/drive_window.rb` is the
driver; `tmp/screenshots` is where its PNGs land.

What that cost while it was believed: the first time this port was presented
it aborted during startup, on the accessible labels, which had been written
from the typelib and never run (defect 10). The source had read as correct for
a whole round.

Still true: the two specs that require `gtk4` are not the reason the suite does
not run here. `spec/spec_helper.rb` requires `kettle/test/rspec`, which is not
in this checkout's bundle and cannot be fetched offline, so no example runs at
all. See `TEST_PARITY.md`.

## 6 — `sqlite3` is missing from the packaged app's bundle

`nix/Gemfile` holds the runtime gems for `flake.nix`'s `bundlerEnv`, and
adding `sqlite3` to it requires `nix/gemset.nix` to be regenerated by
`bundix`, which needs network access. A Gemfile naming a gem the gemset does
not hold fails the build outright, so the gem is not listed there.

What the user loses: the app built by `nix build` raises `LoadError` on
`require "sqlite3"` the first time a search reaches the database. The gem
built from `wordbook-rb.gemspec` is fine — `spec.add_dependency("sqlite3")` is
declared there, along with `gtk4`, `adwaita` and `gettext`.

Closing it: `cd nix && bundle lock && bundix` on a networked machine. The same
run is what `gettext` needed; its entries were lifted by hand from a sibling
port's gemset this round, which is why `gettext` **is** in the bundle and
`sqlite3` is not.

## 7 — the port ships no WordNet archive

Upstream generates `wn-<version>.db.zst` at build time with
`scripts/generate-wn-db.py` and the Python `wn` package, and installs it into
`pkgdatadir`. The port reads that file's SQLite schema directly
(`lib/wordbook/base.rb:159`) but builds no archive and ships none, so unless
upstream Wordbook is installed alongside it, every search lands on the
"Database not found" page.

Generating it needs the `wn` package, which is Python. A Ruby
`generate-wn-db.py` would have to read Open English WordNet's XML and write
`wn`'s schema itself.

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
