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
| Ruby | 3.4 |

## 1 — `Adwaita::Application` cannot be constructed

`Adwaita::Application.new(app_id, flags)` fails from these bindings, so the
port's application is a `Gtk::Application`
(`lib/wordbook/application.rb:86`). Every other Adwaita widget works inside
it, and `Adwaita::StyleManager.default` still sets the colour scheme, so the
only thing actually lost is the automatic resource loading
`Adw.Application.do_startup` performs — see defect 3 for what that costs.

Upstream: `wordbook/main.py:20` — `class Application(Adw.Application)`.

## 2 — `Adwaita::ApplicationWindow` cannot be constructed

The same shape of failure, and this one is expensive: `Adw.Breakpoint` can
only be installed on an `AdwWindow` or `AdwApplicationWindow`
(`adw_application_window_add_breakpoint`), so a `Gtk::ApplicationWindow`
cannot hold the breakpoint upstream declares in `window.blp:54`.

What the user loses: upstream collapses the sidebar whenever the window is
narrower than `550sp`, evaluated by libadwaita against the window's
allocation. The port watches `notify::default-width`, `notify::maximized`,
`notify::fullscreened` and `map` instead (`lib/wordbook/window.rb`,
`update_collapse`), and those are not the same set of size changes: a resize
that changes the allocation without changing the default size does not fire
one. The threshold itself is now scaled the way `sp` is, so text scaling no
longer shifts the two apart — only the trigger does.

Closing it properly needs `Adwaita::ApplicationWindow` to work, or a
`Gtk::Widget` subclass registered from Ruby whose `measure` and
`size_allocate` can be overridden.

## 3 — `Adwaita::ShortcutsItem` takes positional arguments and no action name

`Adwaita::ShortcutsItem.new` raises on no arguments with a message advertising
the signature as `title: utf8, accelerator: utf8`, and then rejects keyword
arguments; `new(title, accelerator)` works. There is no way through the
binding to set `action-name`, which is what upstream's rows carry
(`shortcuts-dialog.blp:298` and the seven after it) and what lets Adwaita look
up the accelerator the application actually bound.

Consequence: the port has to supply accelerator strings itself. It reads them
from `Application::APP_ACCELS`, the same table the accelerators are installed
from (`lib/wordbook/shortcuts_dialog.rb`), so there is one source of truth
rather than two lists to keep in step.

Related: upstream never registers `app.shortcuts` at all — libadwaita
auto-loads `shortcuts-dialog.ui` from the resource base path
(`set_resource_base_path(RES_PATH)`, `main.py:80`). The port has no gresource
bundle, so it installs the action and presents the dialog itself, and it binds
`<Primary>question` to it, which upstream does not bind at all.

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

## 5 — GTK cannot be initialised in the environment this port is written in

`require "gtk4"` calls `gtk_init` at load time and raises
`Gtk::InitError: failed to initialize GTK` here, for every value of
`GDK_BACKEND` and with `DISPLAY` and `WAYLAND_DISPLAY` unset: there is no
display backend of any kind, X11, Wayland or otherwise, and no `Xvfb` or
headless compositor to install offline.

Consequences, all of them real:

- **no screenshot of any unit exists.** Nothing in `COMPONENT_PARITY.md` has
  been looked at on screen. Every verdict there is source against source;
  anywhere a CSS class, a layout or a popover position is said to match, that
  is upstream's arithmetic carried across, not a measurement;
- **no signal has been driven.** `.claude/skills/ruby-gtk-testing` wants the
  window presented and each action fired; `scripts/gtk_driver.rb` cannot
  start, because the app object it drives cannot be loaded;
- **the five accessible labels have never been announced.** Upstream's
  `accessibility { label: … }` is built through
  `Utils.set_accessible_label`, whose shape was read out of the `Gtk-4.0`
  typelib (`gtk_accessible_update_property(n_properties, properties[],
  values[])`) rather than run. The same is true of `compute_bounds`,
  `set_pointing_to`, `Gtk::Window.set_default_icon_name`, the window's
  `focus-widget` property and `Gtk::Settings#gtk_xft_dpi`: all present in the
  typelib, none of them executed;
- **two spec files cannot load.** `spec/wordbook/application_spec.rb` and
  `spec/wordbook/shell_search_provider_spec.rb` require files that require
  `gtk4`. The other 90 examples run and pass. See `TEST_PARITY.md`.

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
