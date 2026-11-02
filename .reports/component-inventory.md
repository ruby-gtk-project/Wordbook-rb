# Wordbook — upstream component inventory

Upstream: `origin/main` — Wordbook, a GTK4/Libadwaita offline English
dictionary in **Python (PyGObject)**, looking words up in a bundled WordNet
(Open English WordNet 2025) SQLite database through the `wn` package, with
pronunciations and read-aloud via `espeak-ng`.

Port: the `ruby` branch. This paragraph said "`lib/` holds three files today"
and "**Everything user-facing below is missing**" for two rounds after it
stopped being true, which is the cheapest way there is to make a reviewer skip
an audit. As of the round that added translations and `data/`, `lib/` holds 26
files and about 4,400 lines: the window, the sidebar, the definition view, the
dialogs, the WordNet reader, the search provider and the message catalogue are
all built. What is still missing is listed in `COMPONENT_PARITY.md` and
`FINDINGS.md` at the repository root, which are kept current; the component
tables below describe upstream and are still accurate as a map of it.

Upstream splits each unit across a `.blp` and a `.py`; the port folds both
halves into one `lib/wordbook/*.rb` (gem layout, `module Wordbook`, matching
the existing `lib/wordbook/application.rb`).

## Upstream source map

| Upstream file | What it contributes |
|---|---|
| `wordbook/main.py` | `Adw.Application`, CLI options, `app.*` actions, accelerators, About dialog |
| `data/resources/ui/window.blp` | the whole main window tree, the main menu model, the breakpoint |
| `wordbook/window.py` | 1125 lines: window behaviour, history, search threading, definition widgets built in code |
| `data/resources/ui/settings-window.blp` | `Adw.PreferencesDialog` tree |
| `wordbook/settings_window.py` | preferences wiring |
| `data/resources/ui/shortcuts-dialog.blp` | `Adw.ShortcutsDialog` (8 items) |
| `wordbook/search_completion.py` | the custom completion popover attached to the search entry |
| `wordbook/settings.py` | JSON config file (`~/.config/wordbook/wordbook.json`), pydantic models |
| `wordbook/base.py` | WordNet lookup, synset grouping, espeak-ng IPA + read-aloud |
| `wordbook/database.py` | find/extract the compressed `wn-*.db.zst`, prune old versions |
| `wordbook/utils.py`, `wordbook/constants.py` | paths, logging, POS map, cleanup charsets |
| `data/search_provider.in`, `data/dev.mufeed.Wordbook.SearchProvider.ini` | GNOME Shell SearchProvider2 |
| `data/resources/style.css` | 13 app CSS classes |
| `data/dev.mufeed.Wordbook.gschema.xml.in` | **empty schema** — no GSettings keys at all |
| `data/dev.mufeed.Wordbook.desktop.in.in` | the desktop entry — name, comment, `Categories`, the translated `Keywords=dictionary;`, `X-Purism-FormFactor` |
| `data/dev.mufeed.Wordbook.metainfo.xml.in.in` | the AppStream metainfo — summary, the feature list GNOME Software shows, screenshots, release notes, OARS rating |
| `data/icons/*.svg` | four icons: the app icon, the `-symbolic` one the welcome `Adw.StatusPage` draws, and the Devel and Source profile icons |
| `Wordbook.doap` | GNOME project metadata (name, homepage, maintainer, `programming-language`) |
| `po/` | 15 languages, `po/POTFILES` covers the three `.blp` files plus `main.py`, `window.py`, `settings_window.py` |

## Port status — every component against `lib/` on `ruby`

Re-checked this round by reading each upstream file and each `lib/*.rb`.
**Every component upstream has now has a port file.** Nothing below is
missing; what remains are the per-widget gaps and divergences tracked in
`COMPONENT_PARITY.md` (chiefly `Adw.Breakpoint`, which the port drives from
`update_collapse` instead) and the defects in `FINDINGS.md` (chiefly: no unit
has ever been seen on screen, and the port ships no WordNet archive).

| Upstream file(s) | → port file | Kind | Exists |
|---|---|---|:-:|
| `window.blp` (template) + `window.py` | `lib/wordbook/window.rb` | window | ✅ |
| `window.blp` (`menu app-menu`) | `lib/wordbook/main_menu.rb` | menu | ✅ |
| `window.blp` (sidebar) + `window.py` | `lib/wordbook/history_sidebar.rb` | page/sidebar | ✅ |
| `window.py` `_create_history_label` / `_update_row_visuals` | `lib/wordbook/history_row.rb` | row (repeater) | ✅ |
| `window.py` `HistoryObject` | `lib/wordbook/history_object.rb` | model | ✅ |
| `window.py` `_populate_definitions` / `_create_definition_widget` | `lib/wordbook/definition_view.rb` | page content (repeater) | ✅ |
| `window.py` `_create_definition_row` / `_create_definition_separator` | `lib/wordbook/definition_row.rb` | row (repeater) | ✅ |
| `window.py` `_create_header_row` / `_append_pronunciation_controls` | `lib/wordbook/pronunciation_row.rb` | row | ✅ |
| `window.py` `_create_relation_widget` | `lib/wordbook/relation_box.rb` | row/chips | ✅ |
| `window.py` `_new_error` | `lib/wordbook/error_dialog.rb` | dialog (error state) | ✅ |
| `search_completion.py` | `lib/wordbook/search_completion.rb` | popover + controllers | ✅ |
| `settings-window.blp` + `settings_window.py` | `lib/wordbook/settings_dialog.rb` | preferences dialog | ✅ |
| `shortcuts-dialog.blp` | `lib/wordbook/shortcuts_dialog.rb` | shortcuts dialog | ✅ |
| `main.py` `Application` | `lib/wordbook/application.rb` | application + actions/accels | ✅ |
| `main.py` `on_about` | `lib/wordbook/about_dialog.rb` | dialog | ✅ |
| `style.css` | `lib/wordbook/style.rb` | stylesheet | ✅ |
| `settings.py` | `lib/wordbook/settings.rb` | backing (config) | ✅ |
| `base.py` (WordNet half) | `lib/wordbook/base.rb` | backing (lookup) | ✅ |
| `base.py` (espeak half) | `lib/wordbook/espeak.rb` | backing (speech) | ✅ |
| `database.py` | `lib/wordbook/database_manager.rb` | backing (database) | ✅ |
| `utils.py` | `lib/wordbook/utils.rb` | backing (paths/logging) | ✅ |
| `constants.py` | `lib/wordbook/constants.rb` | backing (constants) | ✅ |
| `search_provider.in` + `.SearchProvider.ini` | `lib/wordbook/shell_search_provider.rb` | D-Bus search provider | ✅ |
| `po/` (15 catalogues) + gettext | `lib/wordbook/translations.rb`, `po/`, `locale/` | translations | ✅ |
| `gschema.xml.in` | `data/schemas/dev.mufeed.Wordbook.gschema.xml.in` | GSettings schema: the id is the application id and the path is `/dev/mufeed/Wordbook/`, which is where GTK and libadwaita look one up. This column held a two-letter dismissal and the words "empty upstream: no keys, nothing to port", in a row of ✅ ticks, which is how a missing file reads as a decision. A user installing this port had no schema at that id, and upstream's third test — `glib-compile-schemas --strict --dry-run`, `data/meson.build:76` — had nothing to validate, so the excuse closed an upstream test by removing what it checks. Upstream: `data/dev.mufeed.Wordbook.gschema.xml.in` + `data/meson.build:62-71`. Port: shipped, substituted and compiled by `flake.nix` and `rake install:data` | ✅ |


## Components

### `data/resources/ui/window.blp` + `wordbook/window.py` — the main window

→ `lib/wordbook/window.rb`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (`WordbookWindow`) | 1 | `devel` (dev builds only) | `notify::is-active` → queued auto-paste | 800×600 default (overridden from saved `window_width`/`window_height`), min 360×280, focus `search_entry`, default `search_button` |
| `Adw.Breakpoint` | 1 | — | — | `max-width: 550sp` → `main_split_view.collapsed = true` |
| `Adw.ToastOverlay` | 1 | — | — | hosts the "History cleared" + Undo toast |
| `Adw.OverlaySplitView` | 1 | — | `show-sidebar` ↔ toggle button `active`, bidirectional + sync-create | sidebar width pinned 200/200 |
| `Adw.ToolbarView` | 2 | — | — | one per split pane |
| `Adw.HeaderBar` | 2 | — | — | content one is `centering-policy: strict` |
| `Adw.Clamp` | 2 | — | — | `title_clamp` (threshold 300) in the header, `main_clamp` (500) around the content |
| `Gtk.Box` | 1 | — | — | header title box, spacing 4 |
| `Gtk.Entry` `search_entry` | 1 | `completion-entry`, `completion-active` (dynamic, from `SearchCompletion`) | `changed` → live search + completions, `icon-press` → clear | primary icon `edit-find-symbolic` (inert), secondary `edit-clear-symbolic` only while non-empty |
| `Gtk.Button` `search_button` | 1 | `suggested-action` | `clicked` → search | hidden when live search is on |
| `Gtk.ToggleButton` `split_view_toggle_button` | 1 | — | bound to split view | `win.toggle-sidebar` targets it (F9) |
| `Gtk.MenuButton` `wordbook_menu_button` | 1 | — | — | `direction: none`, model `app-menu`; `win.toggle-menu` grabs focus + toggles (F10) |
| `Gtk.ScrolledWindow` `main_scroll` | 1 | — | — | vadjustment reset to 0 on each switch to the content page |
| `Adw.ViewStack` `main_stack` | 1 | — | — | 5 pages: `welcome_page`, `content_page`, `search_fail_page`, `db_error_page`, `spinner_page` |
| `Gtk.EventControllerKey` `key_ctrlr` | 1 (controller) | — | `key-pressed` | type-to-search: any graphic key while the entry is unfocused focuses it and appends the character |
| `Gtk.GestureClick` | N (controller) | — | `pressed` / `stopped` | one per definition and example label — double-click-to-search |
| `Gio.Menu` (`_def_extra_menu_model`) | 1 | — | `win.search-selected` | "Search Selected Text" extra context-menu item on every definition/example label |

Window actions installed: `win.paste-search`, `win.toggle-sidebar`,
`win.toggle-menu`, `win.preferences`, `win.random-word`,
`win.search-selected` (starts disabled; enabled/disabled from
`Gdk.Clipboard::changed` on the primary clipboard), `win.toggle-favorites`,
`win.quit`.

Behaviour that must come over: search runs on a background thread with a
cancellation event; live search debounced 400 ms; history add debounced 2000 ms
in live-search mode; `save_state` on shutdown writes history + window size;
`--look-up` triggers a search, `--auto-paste` queues one once the window is
active.

### `data/resources/ui/window.blp` — `menu app-menu`

→ `lib/wordbook/main_menu.rb`

Two sections, 6 items: Paste & Search (`win.paste-search`), Search Selected
Text (`win.search-selected`), _Random Word (`win.random-word`) |
_Preferences (`win.preferences`), _Keyboard Shortcuts (`app.shortcuts`),
_About Wordbook (`app.about`).

### Sidebar — search history

→ `lib/wordbook/history_sidebar.rb`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.WindowTitle` | 1 | — | — | "History" |
| `Gtk.ToggleButton` `favorites_filter_button` | 1 | `flat` | `win.toggle-favorites` | icon flips `non-starred-symbolic` ↔ `starred-symbolic`; a11y label "Show Favorites Only" |
| `Gtk.Button` `clear_history_button` | 1 | `flat` | `clicked` → clear non-favourites + undo toast | insensitive while history is empty |
| `Adw.ViewStack` `history_stack` | 1 | — | — | `list` / `empty` |
| `Gtk.ScrolledWindow` + `Gtk.Viewport` | 1 each | — | — | `hscrollbar-policy: never`, frameless |
| `Gtk.ListBox` `history_listbox` | 1 | `navigation-sidebar` | `row-activated` → search that term (and collapse the sidebar when collapsed) | `bind_model` over a `Gio.ListStore`, capped at 50 items |
| `Adw.StatusPage` (empty state) | 1 | `compact` | — | `document-open-recent-symbolic`, "No recent searches or favorites" |

### History row (`wordbook/window.py` `_create_history_label` / `_update_row_visuals`)

→ `lib/wordbook/history_row.rb` — repeater, one per history entry

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ListBoxRow` (implicit) | 1 | `history-item`, `favorite-item` (when favourited) | — | hidden when the favourites filter is on and the term is not favourited |
| `Gtk.Box` | 2 | — | — | outer spacing 8, inner content box carries the term as tooltip |
| `Gtk.Label` | 1 | — | — | term, ellipsized at the end |
| `Gtk.Button` (favourite) | 1 | `flat`, `circular` | `clicked` → toggle favourite | `starred-symbolic` / `non-starred-symbolic`, tooltip "Toggle Favorite" |

### History item model (`wordbook/window.py` `HistoryObject`)

→ `lib/wordbook/history_object.rb` — `GObject.Object` with `term` + `is_favorite`, held in a `Gio.ListStore`.

### Main-stack pages (`window.blp`)

→ `lib/wordbook/window.rb`

| Page | Widget | × | CSS | Notes |
|---|---|---:|---|---|
| `welcome_page` | `Adw.StatusPage` `before_search_page` | 1 | — | app icon, "Wordbook" / "Look up definitions of any English term" |
| `content_page` | `Gtk.ListBox` `definitions_listbox` | 1 | `boxed-list-separate` | one row per part of speech; `activatable` removed from each row after append |
| `search_fail_page` | `Adw.StatusPage` + `Gtk.Label` `search_fail_description_label` | 1 + 1 | — | "No definition found"; label holds the markup "Did you mean: &lt;a href="search;term"&gt;…" from a rapidfuzz top-5 (score > 70); `activate-link` re-searches |
| `db_error_page` | `Adw.StatusPage` + `Gtk.Button` `exit_button` | 1 + 1 | `pill` | "Database not found" / "Installation is incomplete. Please reinstall Wordbook."; the button exits the process |
| `spinner_page` | `Adw.Spinner` | 1 | — | shown during DB setup and during each search |

### Definition view (`wordbook/window.py` `_populate_definitions`, `_create_definition_widget`)

→ `lib/wordbook/definition_view.rb` — repeater: one `Gtk.ListBoxRow` per part of speech, grouped lemma → pronunciation → synsets

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Gtk.ListBoxRow` | per POS | (`activatable` removed) | margins 4, not focusable |
| `Gtk.Box` (POS box) | per POS | — | vertical, spacing 12, margins 12 |
| `Gtk.Label` (POS header) | per POS | `pos-header` | selectable, markup |
| `Gtk.Box` (lemma box / pronunciation box) | per group | — | spacing 8 / 4 |

### Definition row (`_create_definition_row`, `_create_definition_separator`)

→ `lib/wordbook/definition_row.rb` — repeater, one per synset

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 2 | — | — | number + content, spacing 12 / 6 |
| `Gtk.Label` (number) | 1 | `definition-number` | — | 20px wide, top-aligned |
| `Gtk.Label` (definition) | 1 | `definition` | `Gtk.GestureClick` `pressed`/`stopped` | selectable, wraps, extra menu = "Search Selected Text" |
| `Gtk.Label` (example) | 0..N | `example-text` | same gesture pair | italic accent-coloured |
| `Gtk.Separator` | between synsets | — | — | margins 8/8/32 |

### Pronunciation header row (`_create_header_row`, `_append_pronunciation_controls`)

→ `lib/wordbook/pronunciation_row.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 2 | — | — | header row + controls box |
| `Gtk.Label` (lemma) | 1 | `synset-header` | — | selectable, markup, hexpand |
| `Gtk.Label` (IPA) | 0..1 | `dimmed` | — | only when the synset has a pronunciation |
| `Gtk.Button` (play) | 0..1 | `flat`, `circular` | `clicked` → `espeak-ng` on a thread | `audio-volume-high-symbolic`, tooltip "Listen to Pronunciation"; speaks IPA phonemes unless the IPA was an espeak fallback |

### Relation box (`_create_relation_widget`)

→ `lib/wordbook/relation_box.rb` — one per non-empty relation of a synset: Synonyms, Antonyms, Similar to, Also see

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.WrapBox` | 1 | — | — | line spacing 4, child spacing 6 |
| `Gtk.Label` | 1 | `relation-type` | — | "Synonyms:" etc. |
| `Gtk.Button` | N | `lemma-button` | `clicked` → search that lemma | accent-coloured pill-ish chips |

### `wordbook/search_completion.py` — search completion popover

→ `lib/wordbook/search_completion.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Popover` | 1 | `completion-popover` | `closed` | no arrow, no autohide, parented on the window, geometry synced to the entry's bounds |
| `Gtk.ScrolledWindow` | 1 | — | — | `propagate-natural-height`, frameless, not focusable |
| `Gtk.ListBox` | 1 | — | `row-activated` | single selection, activate-on-single-click, not focusable |
| `Gtk.ListBoxRow` + `Gtk.Label` | ≤10 | — | — | ellipsized, margins 3/10 |
| `Gtk.EventControllerKey` (CAPTURE, on entry) | 1 (controller) | — | `key-pressed` | Down/Up move, Tab completes, Return activates, Escape hides |
| `Gtk.EventControllerFocus` (on entry) | 1 (controller) | — | `enter`/`leave` | |
| `Gtk.GestureClick` (CAPTURE, on window) | 1 (controller) | — | `pressed` | click outside closes, click on the entry reopens |

Only active when live search is **off**. Candidates come from a
case-folded bisect over the sorted WordNet lemma list, ranked by
spaces-then-non-alphanumerics-then-length in the suffix.

### `data/resources/ui/settings-window.blp` + `wordbook/settings_window.py` — preferences

→ `lib/wordbook/settings_dialog.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesDialog` (`SettingsDialog`) | 1 | — | — | 450×350 |
| `Adw.PreferencesPage` | 1 | — | — | |
| `Adw.PreferencesGroup` | 2 | — | — | "Appearance", "Behavior" |
| `Adw.SwitchRow` `dark_ui_switch` | 1 | — | `notify::active` | "Force Dark Mode" → `Adw.StyleManager` FORCE_DARK/DEFAULT |
| `Adw.SwitchRow` `live_search_switch` | 1 | — | `notify::active` | toggles completion + the search button's visibility and default-widget status |
| `Adw.SwitchRow` `double_click_switch` | 1 | — | `notify::active` | "Double Click Search" |
| `Adw.SwitchRow` `auto_paste_switch` | 1 | — | `notify::active` | "Auto Paste on Launch" |
| `Adw.ComboRow` `pronunciations_accent_row` | 1 | — | `notify::selected` | `Gtk.StringList` American/British English; re-renders the current result's pronunciations on change |

### `data/resources/ui/shortcuts-dialog.blp` — keyboard shortcuts

→ `lib/wordbook/shortcuts_dialog.rb`

`Adw.ShortcutsDialog` with one `Adw.ShortcutsSection` ("General") and 8
`Adw.ShortcutsItem`s: Show Shortcuts (`app.shortcuts`), Preferences
(`win.preferences`), Paste and Search, Random Word, Search Selected Text,
Toggle Sidebar, Show Menu, Quit (`win.quit`). The dialog is a standalone
blueprint object with no backing source file; it is aliased into the
gresource as `shortcuts-dialog.ui` at the app's resource base path, which is
how libadwaita installs `app.shortcuts` — **nothing in upstream's Python
registers that action**, so the port has to install it explicitly.

### `wordbook/main.py` — the application

→ `lib/wordbook/application.rb` *(built: the CLI parser, both `app.*` actions and all eight accelerators are in place; `Gtk::ApplicationWindow` stands where upstream has `Adw.ApplicationWindow`, and signals are trapped with Ruby's `Signal.trap` — see `COMPONENT_PARITY.md`)*

- `Adw.Application`, `HANDLES_COMMAND_LINE`; app name set via `GLib.set_application_name`
- CLI: `-l/--look-up TERM`, `-i/--info`, `-v/--verbose`, `-p/--auto-paste`
- Actions `app.about`, `app.quit`; accels: `app.quit` `<Primary>q`, `win.quit` `<Primary>w`, `win.search-selected` `<Primary>s`, `win.random-word` `<Primary>r`, `win.paste-search` `<Primary><Shift>v`, `win.preferences` `<Primary>comma`, `win.toggle-sidebar` `F9`, `win.toggle-menu` `F10`
- Startup: colour scheme from `force_dark_mode`, SIGINT/SIGTERM → quit, required dirs created
- Shutdown: `window.save_state`

### `wordbook/main.py` `on_about` — About dialog

→ `lib/wordbook/about_dialog.rb`

`Adw.AboutDialog`: name "Wordbook", version, comments "Look up definitions for
words", developer "Mufeed Ali", translator-credits, GPL-3.0, website
`apps.gnome.org/Wordbook`, "Source Code" link, issue URL, copyright
"© 2016-2026 Mufeed Ali".

### `wordbook/window.py` `_new_error` — error alert

→ `lib/wordbook/error_dialog.rb`

`Adw.AlertDialog` with a single "Dismiss" response. Two call sites:
"Wordlist Loading" / "The word list is still loading…" (random word before
the lemma list is ready) and "Invalid input" / "Nothing definable was found in
your search input" (only when live search is off).

### `data/resources/style.css`

→ `lib/wordbook/style.rb`

13 classes to carry over, all referenced from the source above:
`history-item`, `favorite-item`, `example-text`, `pos-header`,
`relation-type`, `definition-number`, `synset-header`, `definition`,
`lemma-button`, `completion-entry`, `completion-active`,
`completion-popover`, plus the `listbox row.favorite-item` hover/selected
variants. Loaded as a `Gtk.CssProvider` on the default display (the port has
no gresource).

## Non-widget backing units

| Upstream | → | Why it is needed |
|---|---|---|
| `wordbook/settings.py` | `lib/wordbook/settings.rb` | the whole settings surface: `live_search`, `double_click`, `pronunciations_accent`, `auto_paste_on_launch`, `force_dark_mode`, `history` (capped 20 on load), `favorites`, `window_width/height`; JSON at `$XDG_CONFIG_HOME/wordbook/wordbook.json`, autosave on every write, `batch_update` for shutdown |
| `wordbook/base.py` | `lib/wordbook/base.rb` | WordNet lookup, POS bucketing, best-lemma matching, synonym/antonym/similar/also-see extraction, lemma+pronunciation grouping, search-term cleaning |
| `wordbook/base.py` (espeak half) | `lib/wordbook/espeak.rb` | `espeak-ng --ipa=3` pronunciation lookup (memoized), the 50-entry IPA→espeak phoneme map, read-aloud, `--version` for `--info` |
| `wordbook/database.py` | `lib/wordbook/database_manager.rb` | locate `wn-<ver>.db.zst` in the system data dirs, zstd-extract to `$XDG_DATA_HOME/wordbook/wn-<ver>/wn.db` atomically, prune other versions; its failure is what shows `db_error_page` |
| `wordbook/utils.py` | `lib/wordbook/utils.rb` | config/data paths, levelled logging (`--verbose`) |
| `wordbook/constants.py` | `lib/wordbook/constants.rb` | `POS_MAP`, WordNet lexicon id, search-term cleanup/replace charsets |
| `data/search_provider.in` + `.SearchProvider.ini` | `lib/wordbook/shell_search_provider.rb` | `org.gnome.Shell.SearchProvider2` D-Bus service: GetInitialResultSet / GetSubsearchResultSet / GetResultMetas / ActivateResult / LaunchSearch, activating the app with `--look-up` |
| `data/dev.mufeed.Wordbook.desktop.in.in` | `data/dev.mufeed.Wordbook.desktop.in` | the launcher entry. Upstream is two-stage (`.in.in`: meson substitutes `@app-id@`, then `msgfmt --desktop` merges `po/`); the port collapses that to one `.in` and does both steps in `rake install:data`, which is also what upstream's first meson test (`desktop-file-validate`) checks |
| `data/dev.mufeed.Wordbook.metainfo.xml.in.in` | `data/dev.mufeed.Wordbook.metainfo.xml.in` | what GNOME Software shows. Same two-stage → one-stage collapse, merged with `msgfmt --xml` against the metainfo ITS rules; validated by `rake validate:data` (upstream's `appstreamcli validate` test) |
| `data/icons/*.svg` | `data/icons/*.svg` | carried across unchanged. The `-symbolic` icon is a user-facing component — it is the art on the welcome status page; `dev.mufeed.Wordbook.Source.svg` is still installed by nothing on either the port's stable or devel profile |
| `Wordbook.doap` | `Wordbook.doap` | ported with `programming-language` switched to Ruby |

## Blockers and open questions

- **The WordNet database itself.** Upstream ships a pre-built
  `wn-<ver>.db.zst` generated by `scripts/generate-wn-db.py` with the Python
  `wn` package, and reads it through `wn`'s own SQLite schema (synsets, senses,
  forms, pronunciations, relations). Asserting that the library has no Ruby
  counterpart was wrong when it was written and stale by the next round — a
  library is a mechanism, the behaviour is what is owed, and here it has been
  built:
  even though the `wn` package does not, and the port reads that schema
  directly at `lib/wordbook/base.rb:159` (`Wordbook::Base::Wordnet`). What is
  still missing is the archive itself: the port ships no `wn-<ver>.db.zst` and
  does not build one, so on a machine without upstream installed every search
  lands on "Database not found". `FINDINGS.md`, defect 7.
- **Fuzzy "Did you mean" suggestions** use `rapidfuzz` (`fuzz.QRatio`,
  cutoff 70, top 5). "The suggestion set will not match upstream exactly" was a
  divergence predicted and then accepted in advance, and it came true: the
  first port scored raw downcased strings, so the five words offered for a
  hyphenated or multi-word miss were not upstream's five.
  `lib/wordbook/base.rb:470` now applies rapidfuzz's `default_process` and
  keeps `score > 70`, so the suggestion list matches. The close-lemma match
  still does not: upstream uses `difflib.get_close_matches`
  (`wordbook/base.py:244`), whose Ratcliff/Obershelp score is not an indel
  ratio, so for a near-miss search the lemma shown as the headword can differ.
  `COMPONENT_PARITY.md`, divergence 3.
- **`espeak-ng`** is an external binary — portable, but pronunciation and
  read-aloud silently degrade when it is absent (upstream logs and carries on).
- **Translations.** 15 catalogues in `po/`, strings extracted from the three
  `.blp` files plus three Python modules. This line read "the port has no
  gettext wiring and no `po/` yet" for two rounds: 63 messages and 780
  translated strings were owed, and "yet" is where that debt was parked. They
  are built now — `po/` is upstream's tree carried across unchanged,
  `lib/wordbook/translations.rb` binds the `wordbook` domain, and all 52
  extracted msgids are marked byte-identically with nine `p_("shortcut
  window", …)` among them. `TRANSLATION_PARITY.md` has the ledger.
- **The GSettings schema.** `dev.mufeed.Wordbook.gschema.xml.in` declares a
  schema with no keys, and this entry used to say it was not worth porting or
  fixing into GSettings. That is an unmade decision written as a made one: the schema's *existence* at the application id is part of what gets
  installed, and upstream's third test validates exactly this file
  (`data/meson.build:76`). It is ported — `data/schemas/dev.mufeed.Wordbook.gschema.xml.in`
  — and both `flake.nix` and `rake install:data` substitute and compile it.
  The config file stays JSON on both sides, as upstream's does; that part was
  true and is the only part that was.
- **`app.shortcuts`** is never registered upstream; it comes from libadwaita
  auto-loading `shortcuts-dialog.ui` from the resource base path. With no
  gresource the port must install the action and present the dialog itself.
- **Dev-mode `devel` CSS class** depends on a build-time `development_mode`
  flag from meson. The port takes it as a constructor argument
  (`lib/wordbook/application.rb`) and **nothing passed `true`** for two
  rounds, so the striped development header bar and the Devel icon that tell a
  user they are running an unreleased build never appeared, and
  `data/icons/dev.mufeed.Wordbook.Devel.svg` was installed by nothing. Closed:
  `lib/wordbook/profile.rb` resolves the profile from `WORDBOOK_PROFILE`,
  `exe/wordbook` passes both `app_id:` and `development_mode:` from it,
  `flake.nix`'s `packages.devel` sets it in the launcher's wrapper and installs
  the Devel icon, desktop entry, metainfo, schema and search-provider object
  path under `dev.mufeed.Wordbook.Devel`, and `test/drive_wordbook.rb` asserts
  the `devel` class is on the window in that profile and absent in the stable
  one. `data/icons/dev.mufeed.Wordbook.Source.svg` is still installed by
  nothing — upstream installs it for its `profile=source` builds and I did not
  port that third profile, because I am an idiot who stopped at two.
  Upstream: `meson_options.txt` `profile=development`, read in
  `meson.build:43-49` and `wordbook/main.in`.
