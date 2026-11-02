# Component parity — Wordbook-rb

| | |
|---|---|
| Upstream | `main` @ `4b43165` |
| Port | `ruby` @ `a73a55a` |
| Units with parity | **0 / 10** |
| Axes verified at runtime | **0 of 4** — see "What was not checked" |

The port is substantially built: 15 `lib/wordbook/*.rb` files, 4,400 lines, and
the widget/CSS/signal totals are within a handful of upstream's. **Not one unit
has parity**, because the text axis fails everywhere (no string in the port is
marked for translation — see `.reports/translation-parity.md`) and because nine
upstream files have nothing opposite them at all.

## What was not checked, and why that matters

`component-parity` Steps 4 and 5 — run the port, screenshot each unit, drive
every signal and assert the effect — **were not performed**. The `gtk4` gem is
not installed in this checkout (`require "gtk4"` → LoadError outside
`nix develop`), the bundled WordNet database is absent, and the port ships no
test harness that could drive a widget (`spec/` holds `spec_helper.rb` and
nothing else). So every verdict below is from reading source against source.

A connected signal is not a working signal, and a CSS class on a widget is not
a rendered style. **Treat the "parity" marks in the tables as "no gap visible
in the source", not as "verified".**

## Unit 1 — the main window

`data/resources/ui/window.blp` (template root) + `wordbook/window.py`
→ `lib/wordbook/window.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 0 | ✓ `devel` | ✓ `notify::is-active` | ✗ | **gap**: built as `Gtk::ApplicationWindow` (`window.rb:792`), and the `Adw.Breakpoint` inside it is not built — see below |
| `Adw.Breakpoint` | 1 | 0 | — | — | — | **gap**: `max-width: 550sp` → `main_split_view.collapsed` replaced by `notify::default-width` + `notify::maximized` against a raw `550` (`window.rb:401`). `sp` is a *scaled* unit: at 1.25 text scaling upstream collapses at 688px and the port still collapses at 550px. `notify::default-width` also does not fire for every size change a breakpoint observes |
| `Adw.ToastOverlay` | 1 | 1 | — | — | — | parity |
| `Adw.OverlaySplitView` | 1 | 1 | — | ✓ `show-sidebar` ↔ `active`, BIDIRECTIONAL \| SYNC_CREATE | — | parity |
| `Adw.ToolbarView` (content) | 1 | 1 | — | — | — | parity |
| `Adw.HeaderBar` (content) | 1 | 1 | — | — | — | parity, `centering-policy: strict` ✓ |
| `Adw.Clamp` | 2 | 2 | — | — | — | parity, thresholds 300/500 ✓ |
| `Gtk.Box` (search box) | 1 | 1 | — | — | — | parity, spacing 4 + hexpand ✓ |
| `Gtk.Entry` `search_entry` | 1 | 1 | ✓ `completion-entry`, `completion-active` | ✓ `changed`, `icon-press` | ✗ | **gap (text)**: `_("Clear")` tooltip is a bare literal (`window.rb:867`). Behaviour also diverges — see "Behaviour divergences" |
| `Gtk.Button` `search_button` | 1 | 1 | ✓ `suggested-action` | ✓ `clicked` | ✗ | **gap**: `_("Search")` unmarked, and the `accessibility { label: _("Search") }` upstream attaches is not built |
| `Gtk.ToggleButton` `split_view_toggle_button` | 1 | 1 | — | ✓ bound | ✗ | **gap**: `_("Show History")` unmarked; `accessibility { label }` not built |
| `Gtk.MenuButton` `wordbook_menu_button` | 1 | 1 | — | — | ✗ | **gap**: `_("Main Menu")` unmarked; `accessibility { label }` not built; `direction: none` ✓, `receives-default` ✓ |
| `Gtk.ScrolledWindow` `main_scroll` | 1 | 1 | — | — | — | parity, vadjustment reset on switch to content ✓ |
| `Adw.ViewStack` `main_stack` | 1 | 1 | — | — | — | parity, 5 pages by the same names ✓ |
| `Adw.StatusPage` welcome | 1 | 1 | — | — | ✗ | **gap**: `_("Wordbook")`, `_("Look up definitions of any English term")` unmarked. Also `icon-name: dev.mufeed.Wordbook-symbolic` resolves to nothing — the port ships no icon |
| `Gtk.ListBox` `definitions_listbox` | 1 | 1 | ✓ `boxed-list-separate` | — | — | parity (in `definition_view.rb`); margins 12/12/8/12 ✓ |
| `Adw.StatusPage` search-fail | 1 | 1 | — | — | ✗ | **gap**: `_("No definition found")` unmarked |
| `Gtk.Label` `search_fail_description_label` | 1 | 1 | — | ✓ `activate-link` | ✗ | **gap**: "Did you mean: …?" is a bare interpolated literal (`window.rb:364`). Upstream's is also unmarked, so this is parity *and* an upstream bug the port inherited — carry it marked, per `translation-parity` |
| `Adw.StatusPage` db-error | 1 | 1 | — | — | ✗ | **gap**: `_("Database not found")`, `_("Installation is incomplete. Please reinstall Wordbook.")` unmarked |
| `Gtk.Button` `exit_button` | 1 | 1 | ✓ `pill` | ✓ `clicked` | ✗ | **gap**: `_("Exit")` unmarked. Behaviour diverges: upstream `sys.exit()`, port `@app.quit` — which runs `shutdown` and therefore `save_state`, so the port writes history where upstream discards it |
| `Adw.Spinner` | 1 | 1 | — | — | — | correspondence: `Adwaita::Spinner` when the bindings have it, else `Gtk::Spinner` (`window.rb:953`). Both branches are in the port's widget stream; only one exists at runtime |
| `Gtk.EventControllerKey` `key_ctrlr` | 1 | 1 | — | ✓ `key-pressed` | — | **gap (behaviour)**: upstream gates on `state & accelerator_get_default_mod_mask() in (SHIFT_MASK, 0)`; the port's `SHORTCUT_MASK` (`window.rb:58`) omits `HYPER_MASK`, so Hyper+key types a character into the entry where upstream propagates it |
| `Gio.Menu` (`_def_extra_menu_model`) | 1 | 1 | — | ✓ `win.search-selected` | ✗ | **gap**: `_("Search Selected Text")` unmarked (`window.rb:965`) |
| — | 0 | 1 | — | `close-request` | — | **extra, explained**: the port saves state on `close-request` as well as on the application's `shutdown`. Upstream saves only in `do_shutdown` |

Window actions: upstream installs 8 (`paste-search`, `toggle-sidebar`,
`toggle-menu`, `preferences`, `random-word`, `search-selected`,
`toggle-favorites`, `quit`); the port installs the same 8 from the
`WINDOW_ACTIONS` loop at `window.rb:585`. `search-selected` starts disabled and
is driven from the primary clipboard's `changed` on both sides. **parity.**

Not built, from `window.blp`'s template header and `window.py.__init__`:

- `focus-widget: search_entry` — the port only calls
  `grab_focus_without_selecting` at the end of `complete_initialization`
  (`window.rb:478`), so before the database finishes extracting the entry is
  not the focus widget. **gap.**
- `set_default_icon_name(app.app_id)` (`window.py:129`) — never called in the
  port. **gap.**
- `default-widget: search_button` is set unconditionally in the blp and the port
  sets it only when live search is off (`window.rb:575`). Upstream's
  `setup_widgets` also sets it conditionally, so the blp's declaration is the
  unconditional half the port drops. **gap**, small.

Stylesheet: `lib/wordbook/style.rb`'s heredoc is **byte-identical** to
`data/resources/style.css`. All 13 app classes and the three
`listbox row.favorite-item` variants are present with the same rules.
**clean** — but unverified, since the port was never rendered.

Messages: 19 upstream msgids reach this unit; **0** are marked in the port.

Driven: not attempted.
Screenshot: none.

## Unit 2 — `menu app-menu`

`data/resources/ui/window.blp` (menu block) → `lib/wordbook/main_menu.rb`

6 items in 2 sections, same labels, same mnemonics, same action names,
same order. Widget axis: n/a (a `Gio::Menu` holds no widgets). Behaviour: ✓.

| | Up | Port | Verdict |
|---|---|---|---|
| items | 6 | 6 | parity |
| actions | `win.paste-search`, `win.search-selected`, `win.random-word`, `win.preferences`, `app.shortcuts`, `app.about` | identical | parity |
| Text | 6 marked msgids | 0 marked | **gap** — all six are bare literals in `main_menu.rb:12-25`, mnemonic underscores preserved |

## Unit 3 — the history sidebar

`window.blp` (sidebar half) + `window.py` → `lib/wordbook/history_sidebar.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Adw.WindowTitle` | 1 | 1 | — | — | ✗ | **gap**: `_("History")` unmarked |
| `Gtk.ToggleButton` `favorites_filter_button` | 1 | 1 | ✓ `flat` | ✓ | ✗ | **gap**: `_("Show Favorites Only")` unmarked **twice** upstream — once as the tooltip, once as `accessibility { label }`. The port has the tooltip as a literal and **no accessible label at all**. Also `action-name: "win.toggle-favorites"` is replaced by a `toggled` handler plus the window action flipping the button (`history_sidebar.rb:50`) — a correspondence, located |
| `Gtk.Button` `clear_history_button` | 1 | 1 | ✓ `flat` | ✓ `clicked` | ✗ | **gap**: `_("Clear History")` unmarked, `accessibility { label }` not built; `sensitive: false` initial ✓ |
| `Adw.ViewStack` `history_stack` | 1 | 1 | — | — | — | parity, `list`/`empty`, vexpand ✓ |
| `Gtk.ScrolledWindow` | 1 | 1 | — | — | — | parity, `hscrollbar-policy: never` + `has-frame: false` ✓ |
| `Gtk.Viewport` | 1 | 0 | — | — | — | correspondence: GTK4's `GtkScrolledWindow` wraps a non-scrollable child in a viewport itself, and `GtkListBox` is not scrollable (`history_sidebar.rb:24`) |
| `Gtk.ListBox` `history_listbox` | 1 | 1 | ✓ `navigation-sidebar` | ✓ `row-activated` | — | parity; `bind_model` over a `Gio::ListStore`, 50-item cap ✓, dedup-and-move-to-top ✓ |
| `Adw.StatusPage` (empty) | 1 | 1 | ✓ `compact` | — | ✗ | **gap**: `_("No recent searches or favorites")` unmarked |
| `Gio.ListStore` | 1 (type) | 1 | — | ✓ `items-changed` | — | parity |

Toast on clear: `_("History cleared")` + `_("Undo")`, both unmarked in the port
(`history_sidebar.rb:109`, `window.rb:759`). Undo restores at the recorded
indices ✓.

## Unit 4 — the history row

`window.py` `_create_history_label` / `_update_row_visuals`
→ `lib/wordbook/history_row.rb`

| Widget | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Gtk.ListBoxRow` | 1 | 1 | ✓ `history-item`, `favorite-item` | — | — | parity, visibility driven by the filter ✓ |
| `Gtk.Box` | 2 | 2 | — | — | — | parity, spacing 8 / 0, tooltip on the inner box ✓ |
| `Gtk.Label` | 1 | 1 | — | — | — | parity, ellipsize END, halign START, margins 8 ✓ |
| `Gtk.Button` | 1 | 1 | ✓ `flat`, `circular` | ✓ `clicked` | ✗ | **gap**: `_("Toggle Favorite")` unmarked |

## Unit 5 — the definition view, row, pronunciation header and relation box

`window.py` `_populate_definitions`, `_create_definition_widget`,
`_create_definition_row`, `_create_definition_separator`, `_create_header_row`,
`_append_pronunciation_controls`, `_create_relation_widget`
→ `definition_view.rb`, `definition_row.rb`, `pronunciation_row.rb`,
`relation_box.rb`

Every widget, spacing, margin, alignment, size request and CSS class matches,
including the `activatable`-removed-after-append trick and the 20px number
column. The gestures match as a pair (`pressed` then `stopped`).

| Row | Verdict |
|---|---|
| all widget/CSS/signal rows | parity |
| `Adw.WrapBox` | correspondence: `Gtk::FlowBox` where the bindings predate libadwaita 1.7 (`relation_box.rb:38`). Both branches in the port's stream, one at runtime |
| `_("Listen to Pronunciation")` | **gap**: unmarked (`pronunciation_row.rb:88`) |
| `"Synonyms"/"Antonyms"/"Similar to"/"Also see"` | parity — upstream does not mark these either |

## Unit 6 — the search completion popover

`wordbook/search_completion.py` → `lib/wordbook/search_completion.rb`

Widget, CSS and signal axes match one for one, including the three controllers,
the two CAPTURE propagation phases, the leading-whitespace-preserving Tab
completion, the Down/Up/Tab/Return/Escape key set and the pick-based
click-outside dismissal.

| | Verdict |
|---|---|
| `Gtk.Popover` parent | **gap**: upstream `set_parent(window)` + `_sync_geometry()` on every update — `compute_bounds(parent)`, `set_pointing_to(rect)`, `set_offset(0,0)`, and `hide()` when `compute_bounds` fails. The port parents to the entry and only syncs the width (`search_completion.rb:37`, `:169`). The popover's position is now whatever GTK picks for an entry-parented `:bottom` popover rather than a 1px-tall rect at the entry's bottom edge, and the geometry-failure hide path does not exist |
| `entry_width` | upstream `max(round(bounds.width), entry.get_width(), 1)`; port `[@entry.width, 1].max` — the bounds term is gone with the geometry pass |
| Text | n/a — this unit shows no strings of its own. parity |

## Unit 7 — preferences

`data/resources/ui/settings-window.blp` + `wordbook/settings_window.py`
→ `lib/wordbook/settings_dialog.rb`

| Widget | Up × | Port × | Signals | Text | Verdict |
|---|---:|---:|---|:-:|---|
| `Adw.PreferencesDialog` | 1 | 1 | — | ✗ | **gap**: the port sets `title = "Preferences"` (`settings_dialog.rb:25`); upstream sets no title. An **extra** untranslated string, and a visible header where upstream has none |
| `Adw.PreferencesPage` | 1 | 1 | — | — | parity |
| `Adw.PreferencesGroup` | 2 | 2 | — | ✗ | **gap**: `_("Appearance")`, `_("Behavior")` unmarked |
| `Adw.SwitchRow` | 4 | 4 | ✓ `notify::active` ×4 | ✗ | **gap**: 7 msgids (4 titles + 3 subtitles) unmarked |
| `Adw.ComboRow` | 1 | 1 | ✓ `notify::selected` | ✗ | **gap**: `_("Pronunciations Accent")` unmarked. The two model strings are unmarked upstream too — parity |

Behaviour: all five handlers match, including the early return when the accent
has not changed and the live-search switch's three side effects on the window.
**parity.**

## Unit 8 — keyboard shortcuts

`data/resources/ui/shortcuts-dialog.blp` → `lib/wordbook/shortcuts_dialog.rb`

| | Up | Port | Verdict |
|---|---|---|---|
| `Adw.ShortcutsDialog` | 1 | 1 | parity |
| `Adw.ShortcutsSection` | 1 | 1 | parity ("General") |
| `Adw.ShortcutsItem` | 8 | 8 | parity in count and order |
| How the accelerator is found | `action: "win.preferences"` etc. — Adwaita resolves the accel from the application at display time | literal strings `"<Control>comma"` etc. (`shortcuts_dialog.rb:18-25`) | **gap**: the port's dialog can now disagree with the real binding. Rebinding an accelerator changes what the app does and not what the dialog says |
| `app.shortcuts` accel | **unbound** upstream | `<Primary>question` (`application.rb:36`) | **extra**, and it is what makes the port's "Show Shortcuts" row show an accelerator upstream's cannot. Explained, not removed |
| `msgctxt "shortcut window"` | 9 keys carry it | none | **gap** — see `translation-parity.md` |
| Dialog title | not set upstream | `"Keyboard Shortcuts"` | **extra** untranslated string |

How upstream gets `app.shortcuts` at all: `do_startup` calls
`set_resource_base_path(RES_PATH)` and libadwaita auto-loads
`shortcuts-dialog.ui` from there, installing the action. The port has no
gresource and installs the action itself (`application.rb:190`) — a
correspondence, located.

## Unit 9 — the application

`wordbook/main.py` → `lib/wordbook/application.rb` + `lib/wordbook/about_dialog.rb`

| | Up | Port | Verdict |
|---|---|---|---|
| base class | `Adw.Application` | `Gtk::Application` | correspondence: `Adwaita::Application` is unusable from these bindings (`application.rb:22`). The style manager is still Adwaita's |
| flags | `HANDLES_COMMAND_LINE` | `:handles_command_line` | parity |
| `GLib.set_application_name` / `set_prgname` | ✓ | ✓ | parity — but upstream marks the name `_("Wordbook")`, the port does not |
| `set_resource_base_path` | ✓ | — | **gap**: no gresource, so no resource-based icons and no auto-installed `app.shortcuts` (worked around) |
| CLI options | 4, via `add_main_option` | 4, hand-parsed (`application.rb:52`) | correspondence — same long and short forms. **But**: `--look-up` with no following argument gives `arguments[index+1].to_s` → `""`, and `OPTIONS.fetch(argument.split("=").first)` means a *value* equal to `-i` or `--verbose` is also read as a flag. Upstream's GOption parser does neither |
| `app.about`, `app.quit` | 2 actions | 3 (`about`, `shortcuts`, `quit`) | `shortcuts` is the documented correspondence above |
| accelerators | 8 | 9 | the extra is `app.shortcuts` |
| SIGINT/SIGTERM | `GLib.unix_signal_add` | `Signal.trap` | correspondence (`application.rb:28`) |
| `do_shutdown` → `save_state` | ✓ | ✓ | parity |
| `--info` prints and returns 0 without activating | ✓ | ✓ | parity |
| About dialog fields | 10 + 1 link | 10 + 2 links | **extra**: `add_link("Ruby Port", …)`. Explained |
| About dialog text | 5 marked msgids | 0 marked | **gap** |

## Unit 10 — the GNOME Shell search provider

`data/search_provider.in` + `data/dev.mufeed.Wordbook.SearchProvider.ini` +
`data/dev.mufeed.Wordbook.SearchProvider.service.in`
→ `lib/wordbook/shell_search_provider.rb` + `exe/wordbook-search-provider`

The five `org.gnome.Shell.SearchProvider2` methods, the node XML, the
`IS_SERVICE` flag, the 10-second inactivity timeout, the UUID keys, the
id/name/description metas and the `--look-up` spawn are all ported.

**And none of it can ever run.** The port ships no
`dev.mufeed.Wordbook.SearchProvider.ini` (so GNOME Shell does not know the
provider exists), no `.SearchProvider.service` D-Bus activation file (so the
bus cannot start it), and no `.desktop` file for the `DesktopId` the `.ini`
would point at. **gap** — the unit is code with no way in.

## Files with nothing opposite them

| Upstream file | What the user loses |
|---|---|
| `data/dev.mufeed.Wordbook.desktop.in.in` | no application launcher, no `Categories=Dictionary;Education;GTK;`, no `Keywords=dictionary;`, no `X-Purism-FormFactor`. 3 msgids |
| `data/dev.mufeed.Wordbook.metainfo.xml.in.in` | no AppStream entry — the app cannot appear in Software. 10 msgids, none of which upstream ever extracted either |
| `data/dev.mufeed.Wordbook.SearchProvider.ini` | the shell never finds the search provider |
| `data/dev.mufeed.Wordbook.SearchProvider.service.in` | D-Bus cannot activate it |
| `data/icons/dev.mufeed.Wordbook.svg` | no app icon. `AboutDialog#application_icon` is set to the app id and resolves to nothing |
| `data/icons/dev.mufeed.Wordbook-symbolic.svg` | the welcome page's `icon-name` resolves to nothing — the first screen the user sees has a missing-image glyph |
| `data/icons/dev.mufeed.Wordbook.Devel.svg`, `.Source.svg` | no devel/nightly icon variants |
| `data/dev.mufeed.Wordbook.gschema.xml.in` | upstream's schema is empty; nothing is owed. The one row here that is genuinely zero |
| `po/` (15 `.po`, `LINGUAS`, `POTFILES`, `wordbook.pot`) | 780 donated translated strings. See `translation-parity.md` |

## Behaviour divergences found by reading

1. **The entry's clear icon.** Upstream routes it through `trigger_search("")`,
   which returns early on blank input, so the icon does nothing
   (`window.py:491`). The port clears the entry, the completion, the
   definitions and switches to the welcome page (`window.rb:514`). The port is
   more useful and it is still a divergence: a user following upstream's
   behaviour loses their result where upstream kept it.
2. **Suggestion cutoff.** Upstream's markup filter is `score > 70`
   (`window.py:371`); the port's is `score >= cutoff` with `cutoff = 70`
   (`base.rb:489`). A word scoring exactly 70 appears in the port's
   "Did you mean" and not in upstream's.
3. **Suggestion scorer.** `rapidfuzz.fuzz.QRatio` applies
   `utils.default_process` first — lowercase **and strip non-alphanumerics**.
   `Base.ratio` only downcases (`base.rb:502`). Multi-word and hyphenated
   lemmas score differently, so the five suggestions offered differ from
   upstream's on exactly the terms where they matter.
4. **Exit button.** `sys.exit()` upstream vs `@app.quit` in the port — the port
   writes history on the way out, upstream does not.
5. **`zstd`.** Upstream decompresses the bundled database with Python's `zstd`
   module. The port shells out to a `zstd` binary
   (`database_manager.rb:102`). Where that binary is absent the database never
   extracts and the user is shown "Database not found" for an installation that
   is complete.
6. **Runtime dependencies are undeclared.** `gtk4`, `adwaita` and `sqlite3` are
   in the `Gemfile` and in no `spec.add_dependency` in `wordbook-rb.gemspec`.
   A `gem install wordbook-rb` produces an app that raises `LoadError` on
   `require "gtk4"` at line 3 of `application.rb`.
7. **Quick-search modifier mask** — see Unit 1, `Gtk.EventControllerKey`.

## Missing ledgers

The skills in `.claude/skills/` expect four documents at the root of the `ruby`
branch. The port has none of them:

| File | State |
|---|---|
| `PORTING.md` | absent |
| `COMPONENT_PARITY.md` | absent (this report is in `.reports/`, which is not the ledger the skill asks for) |
| `TEST_PARITY.md` | absent |
| `TRANSLATION_PARITY.md` | absent |
| `FINDINGS.md` | absent — and there are at least four binding findings worth recording (`Adwaita::Application`, `Adwaita::ApplicationWindow`, `Adwaita::ShortcutsItem` positional args, `Gio::DBusNodeInfo#interfaces`), currently preserved only as code comments |
