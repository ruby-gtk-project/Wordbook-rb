# Component parity — Wordbook-rb

Every upstream unit against its port. This file is the current ledger; the
point-in-time audit it grew out of is `.reports/component-parity.md`.

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` |
| Units built | 11 / 11 |
| Units **presented on screen** | **11 / 11** — every unit is driven with data in it |
| Axes verified at runtime | widgets ✓, signals ✓, breakpoint ✓, CSS ✓ (the class names are on the widgets and the stylesheet parses); text ✓ against the catalogues |

## Read this before the tables

**This port has now been looked at on screen.** The dev shell runs GTK under
Xvfb — `nix develop --command xvfb-run -a ruby test/drive_wordbook.rb` — and
that driver presents the real application, walks 210 checks over the widgets
GTK actually built, and writes nineteen PNGs to `tmp/shots`. All 210 pass. The
first run of it aborted the application during startup, on the accessible
labels, which had been written out of the typelib and never called
(`FINDINGS.md` 10); the source had read as correct for a whole round.

What that run does and does not settle:

- the window class, the widget tree, the breakpoint and every one of the
  eleven actions are **observed**, not reasoned: the split view is watched
  collapsing at 420px and opening again, and each action is activated through
  the `Gio::SimpleAction` the window registered and checked for what it
  changed. An earlier round checked the actions with
  `Gtk::Widget#activate_action`, which activates nothing in these bindings
  (`FINDINGS.md` 12), so those seven green checks covered nothing;
- nineteen images exist in `tmp/shots` and they have been looked at. They have
  **not** been put beside upstream's and compared pixel for pixel;
- the definition view, the definition rows, the pronunciation header, the
  relation chips and the history rows are now on screen **with data in them**:
  the port still ships no WordNet archive (`FINDINGS.md` 7), so
  `test/wn_fixture.rb` writes a small database in the same schema for the
  driver to search. The "Database not found" page and the condition that
  produces it are checked too;
- the CSS is still unmeasured. A class name below means it is added to the
  widget;
- the text axis is verified by `spec/wordbook/translations_spec.rb`, which
  compares every marker in `lib/` against all fifteen catalogues. `bundle
  exec rspec` itself still fails offline, because `.rspec` loads
  `spec/spec_helper.rb`, which requires `kettle-test` and the project's CI
  coverage stack, not in `nix/Gemfile`. The dev shell's own banner names the
  command that avoids that path — `ruby -e 'require "rspec/core"; exit
  RSpec::Core::Runner.run([...])'` under `xvfb-run` — and that command runs
  the whole suite: 9 files, 160 examples, 0 failures. See `TEST_PARITY.md`.

## Unit 1 — the main window

`data/resources/ui/window.blp` (template root) + `wordbook/window.py`
→ `lib/wordbook/window.rb`

| Widget | Up × | Port × | Text | Verdict |
|---|---:|---:|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | ✓ | **closed this round**: `Adwaita::ApplicationWindow.new(app)` works, and the content goes in through `content=`. `devel` class, `notify::is-active`, `icon-name`, min size, default size from settings all present, and the class is asserted by the driver |
| `Adw.Breakpoint` | 1 | 1 | — | **closed this round**: the condition is parsed from `max-width: 550sp` and the one setter puts `collapsed` on the split view, as the blp declares. The hand-rolled `update_collapse` and its four `notify::` handlers are gone. Observed collapsing at 420px and opening at 900px |
| `focus-widget: search_entry` | 1 | 1 | — | set when the window is built, as the template declares it. GTK then moves the focus elsewhere while the header is insensitive — upstream included, since upstream disables the header the same way while the database extracts |
| `default-widget: search_button` | 1 | 1 | — | set unconditionally, as the template declares it. GTK clears it again when the button is hidden, which live search does on both branches: `window.default_widget` is nil on a running port and on a running upstream |
| `set_default_icon_name(app_id)` | 1 | 1 | — | **closed this round** (`window.py:128`) |
| `Adw.ToastOverlay`, `Adw.OverlaySplitView`, `Adw.ToolbarView`, `Adw.HeaderBar`, `Adw.Clamp` ×2, `Gtk.Box` | 7 | 7 | — | parity, including the `show-sidebar` ↔ `active` bidirectional binding and the 300/500 clamp thresholds |
| `Gtk.Entry` `search_entry` | 1 | 1 | ✓ | parity. The clear icon now routes through `trigger_search("")`, as upstream's does — divergence 1 |
| `Gtk.Button` `search_button` | 1 | 1 | ✓ | parity, with the accessible label built |
| `Gtk.ToggleButton` `split_view_toggle_button` | 1 | 1 | ✓ | parity, accessible label built |
| `Gtk.MenuButton` `wordbook_menu_button` | 1 | 1 | ✓ | parity, accessible label built |
| `Gtk.ScrolledWindow`, `Adw.ViewStack` + 5 pages | 6 | 6 | ✓ | parity; page names identical, vadjustment reset on the switch to content |
| `Adw.StatusPage` welcome | 1 | 1 | ✓ | parity. `icon-name: dev.mufeed.Wordbook-symbolic` now resolves: the icon ships in `data/icons/` and is installed to `share/icons/hicolor/symbolic/apps` |
| `Gtk.Label` `search_fail_description_label` | 1 | 1 | ✓ | parity. "Did you mean: %s?" is now a format string with a real msgid — see `TRANSLATION_PARITY.md` |
| `Adw.StatusPage` db-error + `Gtk.Button` `exit_button` | 2 | 2 | ✓ | parity. The button now exits without running the shutdown handler, so the history is not written — divergence 4 |
| `Adw.Spinner` | 1 | 1 | — | **closed this round**: `Adwaita::Spinner`, the widget upstream puts there. The `Gtk::Spinner` fallback is gone |
| `Gtk.EventControllerKey` | 1 | 1 | — | parity: `SHORTCUT_MASK` is the default modifier mask without Shift, Hyper included — divergence 7 |
| `close-request` → `save_state` | 0 | 1 | — | extra, explained: the port saves on close as well as on the application's shutdown |

## Unit 2 — `menu app-menu`

`window.blp:5-43` → `lib/wordbook/main_menu.rb`

6 items, same labels, same mnemonics, same action names, all six marked with
`N_` in the tables and looked up with `_()` when the menu is built. **parity.**

## Unit 3 — the history sidebar

the `sidebar` half of `window.blp` + the history handling in `window.py`
→ `lib/wordbook/history_sidebar.rb`

All widgets, CSS classes and signals present. `Gtk.Viewport` is absent by
correspondence (GTK4 inserts one around a non-scrollable child). The two
accessible labels upstream attaches — `window.blp:81-82`, `:96-98` — are
**built this round**, with the same msgids. `action-name` on the filter button
is replaced by a `toggled` handler plus the window action flipping the button:
a located correspondence. **parity.**

## Unit 4 — the history row

`_create_history_label` + `_update_row_visuals` → `lib/wordbook/history_row.rb`.
**parity**, with `_("Toggle Favorite")` marked.

## Unit 5 — definition view, row, pronunciation header, relation box

`window.py` `_populate_definitions` and friends → `definition_view.rb`,
`definition_row.rb`, `pronunciation_row.rb`, `relation_box.rb`.
**parity**, with `_("Listen to Pronunciation")` marked.
`Adwaita::WrapBox` is the widget upstream builds and now the widget the port
builds — the `Gtk::FlowBox` substitute is gone. Its reflow has not been
compared with upstream's: the relation chips need a definition on screen, and
the port has no WordNet archive to produce one (`FINDINGS.md` 7).

## Unit 6 — the search completion popover

`wordbook/search_completion.py` → `lib/wordbook/search_completion.rb`

| | Verdict |
|---|---|
| popover parent | **closed this round**: parented to the window, as upstream parents it |
| `_sync_geometry` | **closed this round**: `compute_bounds(parent)`, a 1px-tall rect along the entry's bottom edge, `set_offset(0, 0)`, the width as `max(bounds.width, entry.width, 1)`, and `hide` when `compute_bounds` fails |
| where it actually lands | **unverified** — never rendered |
| strings | none of its own. parity |

## Unit 7 — preferences

`settings-window.blp` + `wordbook/settings_window.py`
→ `lib/wordbook/settings_dialog.rb`

Dialog, page, 2 groups, 4 switch rows, 1 combo row, 5 `notify::` handlers,
11 msgids marked. The invented `title = "Preferences"` is **removed**, so the
dialog has no header where upstream has none. **parity.**

## Unit 8 — keyboard shortcuts

`shortcuts-dialog.blp` → `lib/wordbook/shortcuts_dialog.rb`

1 section, 8 items, in upstream's order, all nine labels marked
`p_("shortcut window", …)`. The invented `title = "Keyboard Shortcuts"` is
**removed**. The rows carry upstream's `action-name` and Adwaita resolves
the accelerator from what the application bound — **closed this round**; the
dialog used to be handed accelerator strings out of `Application::APP_ACCELS`
(`FINDINGS.md` 3). `tmp/screenshots/shortcuts.png` shows the eight rows with
their keys. **parity**, with one addition: `app.shortcuts` is bound to
`<Primary>question`, which upstream binds to nothing.

## Unit 9 — the application

`wordbook/main.py` → `lib/wordbook/application.rb` + `about_dialog.rb`

| | Verdict |
|---|---|
| base class | **closed this round**: `Adwaita::Application`, built with the id and flags positionally |
| `set_resource_base_path` | **closed this round** — called in `on_startup`. There is still no gresource bundle to find, so the icons come from the icon theme (`data/icons/`, installed to the XDG icon directories) and `app.shortcuts` is still installed by hand |
| CLI options | **closed this round**: the parser consumes by position, so `--look-up -i` looks up "-i" and `--look-up` with nothing after it is reported instead of searching for the empty string. 14 examples pin it |
| actions / accelerators | 3 actions, 9 accelerators against upstream's 2 and 8: `app.shortcuts` is the addition, recorded above |
| signals | `GLib.unix_signal_add` → `Signal.trap`: correspondence |
| About dialog | 10 fields, 2 links. `_("Ruby Port")` is an added key, recorded in `TRANSLATION_PARITY.md`. All 5 upstream msgids marked |

## Unit 10 — the GNOME Shell search provider

`data/search_provider.in` + the `.ini` and `.service.in`
→ `lib/wordbook/shell_search_provider.rb` + `exe/wordbook-search-provider`
+ `data/dev.mufeed.Wordbook.SearchProvider.ini` + `.service.in`

The five methods, the node XML, `IS_SERVICE`, the 10-second inactivity
timeout, the UUID keys, the id/name/description metas and the `--look-up`
spawn were already ported. **The way in is built this round**: the `.ini` the
shell reads, the D-Bus `.service` that activates it (pointing at
`@bindir@/wordbook-search-provider`, substituted at install), and the
`.desktop` its `DesktopId` names. `flake.nix` installs all three and wraps
both `exe/` scripts, so `nix build` produces a provider the shell can start.

Not verified: no shell has been asked to search. The provider's behaviour is
pinned by 15 examples in `spec/wordbook/shell_search_provider_spec.rb`, which
cannot be loaded here (`FINDINGS.md` 5).

## Unit 11 — the invalid-input alert

`wordbook/window.py`'s `_new_error` → `lib/wordbook/error_dialog.rb`

An `Adw.AlertDialog` with one "Dismiss" response, raised when a search term
cleans down to nothing: the heading is `Invalid input`, the body is
`Nothing definable was found in your search input`, and the wordlist-loading
variant uses the `Wordlist Loading` heading. Driven: the drive opens it,
reads both strings off the dialog and dismisses it.

This section was missing, and the header above it said `Units built 10 / 10`
over a denominator that had dropped it — the component inventory maps eleven
units, this ledger had ten `## Unit` sections, and `error_dialog.rb`,
`Adw.AlertDialog`, `Invalid input` and `Wordlist Loading` appeared nowhere in
the file. The component is fine and always was; the ratio was wrong.

## Files with nothing opposite them

This table had nine rows, then one, and both counts were arrived at by leaving
out the upstream files that have nothing opposite them — which is the only
reason the table exists. The six restored rows below (`Wordbook.doap`, the
flatpak manifest, `scripts/flatpak-wheel-gen.py`, both screenshots,
`meson_options.txt`) were simply absent from it.

| Upstream file | Port |
|---|---|
| `data/dev.mufeed.Wordbook.desktop.in.in` | `data/dev.mufeed.Wordbook.desktop.in` — same keys, app id substituted, listed in `po/POTFILES` |
| `data/dev.mufeed.Wordbook.metainfo.xml.in.in` | `data/dev.mufeed.Wordbook.metainfo.xml.in`, likewise |
| `data/dev.mufeed.Wordbook.SearchProvider.ini` | present |
| `data/dev.mufeed.Wordbook.SearchProvider.service.in` | present, `@bindir@` substituted at install |
| `data/icons/*.svg` (4) | all four carried across; the app and symbolic icons are installed, the Devel and Source variants are not — nothing in the port sets development mode |
| `po/` | carried across unchanged, plus the port's own `POTFILES` |
| `data/dev.mufeed.Wordbook.gschema.xml.in` | `data/schemas/dev.mufeed.Wordbook.gschema.xml.in`, substituted and compiled by `flake.nix` and `rake install:data`. I had written this row as "nothing owed: upstream's schema is empty and all state is the JSON config file", which is the kind of sentence this ledger exists to stop: a user installing this port got no schema at the id GTK and libadwaita look one up under, and upstream's third test — `glib-compile-schemas --strict --dry-run`, `data/meson.build:76` — had nothing to validate, so my excuse closed an upstream test by deleting the thing it checks. Upstream: `data/dev.mufeed.Wordbook.gschema.xml.in` + `data/meson.build:62-71`. Port: `data/schemas/dev.mufeed.Wordbook.gschema.xml.in` + `flake.nix`'s schema step |
| `scripts/generate-wn-db.py` + `data/meson.build:5-17` | `lib/wordbook/lmf_reader.rb` + `lib/wordbook/database_builder.rb` + `exe/wordbook-generate-db` + `rake wn:db`, with `rake install:data` and `flake.nix` installing `data/wn-*.db.zst` into `share/wordbook`. Upstream hands the XML to the vendored Python `wn`; there is no Ruby `wn`, so the reader streams the WN-LMF lexicon and the builder writes the schema `lib/wordbook/base.rb` reads. Run against the real 2025 lexicon: 161,875 entries, 212,659 senses, 120,564 synsets, a 73.9 MB database, 24.1 MB compressed, and `DatabaseManager.setup` then unpacks it and a search for "serendipity" returns its definition and IPA. `spec/wordbook/database_builder_spec.rb` makes the same round trip on a four-entry lexicon on every run. What this port still does not do is **commit** an archive, and neither does upstream: `install_wn_db` is a meson option, off by default |
| `build-aux/flatpak/dev.mufeed.Wordbook.Devel.json` + `scripts/flatpak-wheel-gen.py` | **ported this round, with an honest divergence**: `build-aux/flatpak/dev.mufeed.Wordbook.Devel.json` builds Ruby 3.4 from source, `pcaudiolib`/`espeak-ng` at the exact git refs upstream's manifest pins, this port's own `rake wn:db` equivalent for the dictionary, and `rake install:data PREFIX=/app` for the desktop/metainfo/schema/search-provider files — the same install path `flake.nix` uses. `.github/workflows/ci.yml`'s `flatpak-builder` job builds it on every push, the way upstream's `CI.yml` does. The divergence: upstream's `scripts/flatpak-wheel-gen.py` pins every Python wheel so the build runs with no network; this port's `wordbook-gems` module instead runs `bundle install --share=network` at build time, because the gemspec's five runtime gems (`gtk4`, `adwaita`, `sqlite3`, `zstd-ruby`, `gettext`) have no committed `Gemfile.lock` checksums to pin from and fetching real ones needs network this environment does not have. `scripts/flatpak-gem-gen.rb` is the Ruby equivalent of the wheel-gen script — given network, it resolves a gem to a pinned `{url, sha256}` flatpak source the same way — but nothing in the manifest depends on its output yet, so the manifest is not proven to build with the `flatpak-builder` tool itself in this environment (no privileged container, no `org.gnome.Sdk` runtime fetched); it is proven syntactically valid JSON and faithful to upstream's module list and pins, not proven to produce a bundle |
| `Wordbook.doap` | `Wordbook.doap`, ported this round. It had no counterpart at all, which left this port invisible to GNOME's own project record |
| `screenshots/light.png`, `screenshots/dark.png` | **closed this round**: the nineteen PNGs `test/drive_wordbook.rb` writes to `tmp/shots` are now committed at `screenshots/*.png`, and `data/dev.mufeed.Wordbook.metainfo.xml.in`'s `<image>` tags point at `raw.githubusercontent.com/ruby-gtk-project/Wordbook-rb/ruby/screenshots/*.png` — four of this port's own screens, not upstream's `light.png`/`dark.png` |
| `meson_options.txt` | `PROFILE` in the `Rakefile` and `packages.devel` in `flake.nix` carry the `profile` option; `install_wn_db` is now `rake wn:db` having been run or not — `rake install:data` and `flake.nix` install `data/wn-*.db.zst` when one is there and say nothing when it is not, which is what the option decides upstream |

## Behaviour divergences

| # | Divergence | State |
|---|---|---|
| 1 | the entry's clear icon emptied the entry, where upstream's does nothing | **closed**: routed through `trigger_search("")`, which returns early on blank input |
| 2 | suggestion cutoff was `>= 70`, upstream keeps `> 70` | **closed**, pinned by an example that scores a pair at exactly 70 |
| 3 | the suggestion scorer downcased only, where `fuzz.QRatio` also replaces non-alphanumerics with spaces | **closed**: `Base.default_process` + `Base.qratio`. **A related divergence remains**: upstream's close-lemma match is `difflib.get_close_matches`, whose Ratcliff/Obershelp score is not an indel ratio, so the headword lemma chosen for a near-miss search can still differ |
| 4 | the exit button ran `@app.quit`, which saved the history; upstream `sys.exit()`s | **closed**: `exit!(0)`, no shutdown handler, nothing written |
| 5 | `SHORTCUT_MASK` omitted `HYPER_MASK`, so Hyper+key typed a character | **closed** |
| 6 | the gemspec declared no runtime dependencies | **closed**: `gtk4`, `adwaita`, `sqlite3`, `gettext` |
| 7 | `DatabaseManager` shells out to the `zstd` program | **closed**: `zstd-ruby` (`FINDINGS.md` 4) |
| 8 | the `Adw.Breakpoint` trigger | **closed**: the breakpoint is installed on the window and observed firing |
| 9 | the five accessible labels raised `NotImplementedError` and aborted the startup | **closed**: built through `Gtk::Builder`'s `<accessibility>` element, which is what blueprint compiles upstream's blocks into (`FINDINGS.md` 10) |
