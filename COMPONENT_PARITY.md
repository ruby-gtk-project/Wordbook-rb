# Component parity — Wordbook-rb

Every upstream unit against its port. This file is the current ledger; the
point-in-time audit it grew out of is `.reports/component-parity.md`.

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` |
| Units built | 10 / 10 |
| Units **verified on screen** | **0 / 10** |
| Axes verified at runtime | text ✓ (specs), widgets/CSS/signals ✗ |

## Read this before the tables

**Nothing in this port has been looked at on screen.** `require "gtk4"` raises
`Gtk::InitError` in the environment it is written in — there is no display
backend of any kind (`FINDINGS.md`, defect 5). So:

- no screenshot of any unit exists, and none has been compared with upstream's;
- no connected signal has been observed firing. "✓ `clicked`" below means the
  handler is connected in the source, not that pressing the button does
  anything;
- no CSS class has been seen to render. A class name below means it is added to
  the widget;
- the popover geometry, the sidebar collapse and the `Gtk::FlowBox` reflow are
  upstream's arithmetic carried across, not measurements.

The one axis that *is* verified is the text: `spec/wordbook/translations_spec.rb`
compares every marker in `lib/` against `po/de.po` and all fifteen catalogues,
and it passes. See `TRANSLATION_PARITY.md`.

## Unit 1 — the main window

`data/resources/ui/window.blp` (template root) + `wordbook/window.py`
→ `lib/wordbook/window.rb`

| Widget | Up × | Port × | Text | Verdict |
|---|---:|---:|:-:|---|
| `Adw.ApplicationWindow` | 1 | 0 | ✓ | correspondence: `Gtk::ApplicationWindow` (`FINDINGS.md` 2). `devel` class, `notify::is-active`, `icon-name`, min size, default size from settings all present |
| `Adw.Breakpoint` | 1 | 0 | — | **gap**: driven from `update_collapse` instead. The `550sp` threshold is now scaled by the text scaling factor, so 1.25 scaling collapses both at 688px; the signals it is evaluated on are still not the allocation changes a breakpoint sees (`FINDINGS.md` 2) |
| `focus-widget: search_entry` | 1 | 1 | — | **closed this round**: set when the window is built, so the entry is focused while the database extracts. It used to be set only at the end of `complete_initialization` |
| `default-widget: search_button` | 1 | 1 | — | **closed this round**: set unconditionally, as the template declares it. It used to be set only when live search was off |
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
| `Adw.Spinner` | 1 | 1 | — | correspondence: `Gtk::Spinner` where the bindings predate 1.6. Neither branch observed |
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
`Adwaita::WrapBox` is substituted by `Gtk::FlowBox` where the bindings predate
libadwaita 1.7; whether the reflow matches is unknown and unmeasured.

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
**removed**. The accelerators are read from `Application::APP_ACCELS` rather
than typed out again, so the dialog cannot disagree with what the app binds;
upstream resolves them from an action name, which the binding cannot do
(`FINDINGS.md` 3). **parity**, with one addition: `app.shortcuts` is bound to
`<Primary>question`, which upstream binds to nothing.

## Unit 9 — the application

`wordbook/main.py` → `lib/wordbook/application.rb` + `about_dialog.rb`

| | Verdict |
|---|---|
| base class | correspondence: `Gtk::Application` (`FINDINGS.md` 1) |
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

## Files with nothing opposite them

Nine at the start of this round, one now.

| Upstream file | Port |
|---|---|
| `data/dev.mufeed.Wordbook.desktop.in.in` | `data/dev.mufeed.Wordbook.desktop.in` — same keys, app id substituted, listed in `po/POTFILES` |
| `data/dev.mufeed.Wordbook.metainfo.xml.in.in` | `data/dev.mufeed.Wordbook.metainfo.xml.in`, likewise |
| `data/dev.mufeed.Wordbook.SearchProvider.ini` | present |
| `data/dev.mufeed.Wordbook.SearchProvider.service.in` | present, `@bindir@` substituted at install |
| `data/icons/*.svg` (4) | all four carried across; the app and symbolic icons are installed, the Devel and Source variants are not — nothing in the port sets development mode |
| `po/` | carried across unchanged, plus the port's own `POTFILES` |
| `data/dev.mufeed.Wordbook.gschema.xml.in` | nothing owed: upstream's schema is empty and all state is the JSON config file |
| `scripts/generate-wn-db.py` | **still nothing.** The port ships no WordNet archive and builds none (`FINDINGS.md` 7) |

## Behaviour divergences

| # | Divergence | State |
|---|---|---|
| 1 | the entry's clear icon emptied the entry, where upstream's does nothing | **closed**: routed through `trigger_search("")`, which returns early on blank input |
| 2 | suggestion cutoff was `>= 70`, upstream keeps `> 70` | **closed**, pinned by an example that scores a pair at exactly 70 |
| 3 | the suggestion scorer downcased only, where `fuzz.QRatio` also replaces non-alphanumerics with spaces | **closed**: `Base.default_process` + `Base.qratio`. **A related divergence remains**: upstream's close-lemma match is `difflib.get_close_matches`, whose Ratcliff/Obershelp score is not an indel ratio, so the headword lemma chosen for a near-miss search can still differ |
| 4 | the exit button ran `@app.quit`, which saved the history; upstream `sys.exit()`s | **closed**: `exit!(0)`, no shutdown handler, nothing written |
| 5 | `SHORTCUT_MASK` omitted `HYPER_MASK`, so Hyper+key typed a character | **closed** |
| 6 | the gemspec declared no runtime dependencies | **closed**: `gtk4`, `adwaita`, `sqlite3`, `gettext` |
| 7 | `DatabaseManager` shells out to the `zstd` program | **open** (`FINDINGS.md` 4) |
| 8 | the `Adw.Breakpoint` trigger | **open** (`FINDINGS.md` 2) |
