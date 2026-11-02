# Wordbook-rb — component identification

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` (Python / PyGObject + blueprint) |
| Port | `ruby` @ `a73a55a` |
| Scanned | 2026-11-02 |
| Scan tool | `.claude/skills/component-identification/scripts/component-scan.sh` with `symbols.tsv` (1301 symbols) |

The upstream side of this inventory already exists as `.reports/component-inventory.md`
and is still accurate about upstream. **Its "Port:" paragraph is not** — it says
`lib/` holds three files and "everything user-facing below is missing", which was
true when it was written and is false now. This document is the port side, built
the same way, so the two can be joined.

## Step 1 — declarative UI on both sides

```
upstream: data/resources/ui/window.blp            (286 lines, 1 template + 1 menu)
          data/resources/ui/settings-window.blp   (47 lines, 1 template)
          data/resources/ui/shortcuts-dialog.blp  (48 lines, 1 standalone object)
port:     none — the house style builds every widget as a memoized method
```

Three upstream template/menu roots, so three unit boundaries handed over for
free; the fourth and fifth units (the application class, and the definition
widgets built entirely in `window.py`) have no declarative root.

## Step 2/3 — scan totals

| | Upstream | Port |
|---|---:|---:|
| Scanned files with rows | 7 | 15 |
| Rows | 155 | 134 |
| Distinct widget types | 28 | 27 |
| Distinct CSS classes | 18 | 16 |
| Distinct signals | 17 | 19 |
| Distinct controller types | 3 | 3 |

The totals are close, which on this port is a true signal rather than a
coincidence: the port is substantially built. The gaps are in the four places a
widget-type total cannot see — accessibility labels, translation markers, the
breakpoint, and everything that lives in `data/`.

## File mapping

```
data/resources/ui/window.blp  (template root)   ┐
wordbook/window.py                              ├─> lib/wordbook/window.rb
                                                │   lib/wordbook/history_sidebar.rb
                                                │   lib/wordbook/history_row.rb
                                                │   lib/wordbook/history_object.rb
                                                │   lib/wordbook/definition_view.rb
                                                │   lib/wordbook/definition_row.rb
                                                │   lib/wordbook/pronunciation_row.rb
                                                │   lib/wordbook/relation_box.rb
                                                │   lib/wordbook/error_dialog.rb
data/resources/ui/window.blp  (menu app-menu)   ┘─> lib/wordbook/main_menu.rb

data/resources/ui/settings-window.blp  ┐
wordbook/settings_window.py            ┴──────────> lib/wordbook/settings_dialog.rb

data/resources/ui/shortcuts-dialog.blp ───────────> lib/wordbook/shortcuts_dialog.rb
wordbook/search_completion.py          ───────────> lib/wordbook/search_completion.rb
wordbook/main.py                       ┬──────────> lib/wordbook/application.rb
                                       └──────────> lib/wordbook/about_dialog.rb
data/resources/style.css               ───────────> lib/wordbook/style.rb

wordbook/settings.py      ───────────────────────> lib/wordbook/settings.rb
wordbook/base.py          ┬──────────────────────> lib/wordbook/base.rb
                          └──────────────────────> lib/wordbook/espeak.rb
wordbook/database.py      ───────────────────────> lib/wordbook/database_manager.rb
wordbook/utils.py         ───────────────────────> lib/wordbook/utils.rb
wordbook/constants.py     ───────────────────────> lib/wordbook/constants.rb
data/search_provider.in   ───────────────────────> lib/wordbook/shell_search_provider.rb

data/dev.mufeed.Wordbook.desktop.in.in              -> NOTHING
data/dev.mufeed.Wordbook.metainfo.xml.in.in         -> NOTHING
data/dev.mufeed.Wordbook.SearchProvider.ini         -> NOTHING
data/dev.mufeed.Wordbook.SearchProvider.service.in  -> NOTHING
data/icons/dev.mufeed.Wordbook.svg                  -> NOTHING
data/icons/dev.mufeed.Wordbook-symbolic.svg         -> NOTHING
data/icons/dev.mufeed.Wordbook.Devel.svg            -> NOTHING
data/icons/dev.mufeed.Wordbook.Source.svg           -> NOTHING
po/  (15 catalogues, LINGUAS, POTFILES, wordbook.pot) -> NOTHING
```

Nine upstream files with nothing opposite them. Per `component-parity` Step 2
that is the first and largest kind of gap, and it is found here rather than in
any diff.

## Components — port side

### `lib/wordbook/window.rb` — the main window

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk::ApplicationWindow` | 1 | `devel` (when `development_mode`) | `notify::is-active`, `notify::default-width`, `notify::maximized`, `close-request` | title "Wordbook", icon `accesories-dictionary`, default size from settings, min 360×280 |
| `Adwaita::ToastOverlay` | 1 | — | — | hosts the clear-history toast |
| `Adwaita::OverlaySplitView` | 1 | — | `show-sidebar` ↔ toggle `active`, BIDIRECTIONAL \| SYNC_CREATE | sidebar pinned 200/200 |
| `Adwaita::ToolbarView` | 1 | — | — | content pane; the sidebar's is in `history_sidebar.rb` |
| `Adwaita::HeaderBar` | 1 | — | — | `centering_policy = :strict` |
| `Adwaita::Clamp` | 2 | — | — | `title_clamp` 300, `main_clamp` 500 |
| `Gtk::Box` | 1 | — | — | `search_box`, horizontal 4, hexpand |
| `Gtk::Entry` | 1 | `completion-entry`, `completion-active` (both attached from `SearchCompletion`) | `changed`, `icon-press` | primary `edit-find-symbolic` inert, secondary `edit-clear-symbolic` only while non-empty, `activates_default` |
| `Gtk::Button` `search_button` | 1 | `suggested-action` | `clicked` | `receives_default`, tooltip "Search" |
| `Gtk::ToggleButton` | 1 | — | bound to split view | tooltip "Show History" |
| `Gtk::MenuButton` | 1 | — | — | `direction = :none`, model from `MainMenu` |
| `Gtk::ScrolledWindow` | 1 | — | — | `hscrollbar_policy = :never`, vadjustment reset on each switch to content |
| `Adwaita::ViewStack` | 1 | — | — | 5 pages added by `add_named` |
| `Adwaita::StatusPage` | 3 | — | — | welcome, search-fail, db-error |
| `Gtk::Label` | 1 | — | `activate-link` | `search_fail_description_label`, markup, selectable |
| `Gtk::Button` `exit_button` | 1 | `pill` | `clicked` → `@app.quit` | — |
| `Adwaita::Spinner` *or* `Gtk::Spinner` | 1 | — | — | conditional on `Adwaita.const_defined?(:Spinner)` |
| `Gtk::EventControllerKey` | 1 (controller) | — | `key-pressed` | type-to-search |
| `Gio::Menu` | 1 | — | `win.search-selected` | the definitions' extra context menu |

Window actions, installed from the `WINDOW_ACTIONS` loop at `window.rb:585`
(invisible to the scan): `paste-search`, `toggle-sidebar`, `toggle-menu`,
`preferences`, `random-word`, `search-selected` (starts disabled, enabled from
the primary clipboard's `changed`), `toggle-favorites`, `quit`.

Repeaters: none here. Conditional: the `devel` class, and the spinner's class.

### `lib/wordbook/main_menu.rb` — the header-bar menu model

`Gio::Menu`, two sections, 6 items — no widget rows, so no scan rows at all.
Labels and actions: Paste & Search / `win.paste-search`, Search Selected Text /
`win.search-selected`, _Random Word / `win.random-word` ‖ _Preferences /
`win.preferences`, _Keyboard Shortcuts / `app.shortcuts`, _About Wordbook /
`app.about`.

### `lib/wordbook/history_sidebar.rb` — the sidebar

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adwaita::ToolbarView` | 1 | — | — | — |
| `Adwaita::HeaderBar` | 1 | — | — | — |
| `Adwaita::WindowTitle` | 1 | — | — | "History" (positional args) |
| `Gtk::ToggleButton` | 1 | `flat` | `toggled` | icon flips `non-starred-symbolic` ↔ `starred-symbolic`, tooltip "Show Favorites Only" |
| `Gtk::Button` | 1 | `flat` | `clicked` | `user-trash-symbolic`, tooltip "Clear History", insensitive while empty |
| `Adwaita::ViewStack` | 1 | — | — | `list` / `empty` |
| `Gtk::ScrolledWindow` | 1 | — | — | `hscrollbar_policy = :never`, frameless |
| `Gtk::ListBox` | 1 | `navigation-sidebar` | `row-activated` | `bind_model` over a `Gio::ListStore`, cap 50 |
| `Adwaita::StatusPage` | 1 | `compact` | — | `document-open-recent-symbolic`, "No recent searches or favorites" |
| `Gio::ListStore` | 1 (type) | — | `items-changed` | holds `HistoryObject`s |

### `lib/wordbook/history_row.rb` — repeater, one per history entry

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk::ListBoxRow` (the list box's own) | 1 | `history-item`, `favorite-item` (conditional) | — | `visible = !favorites_only \|\| favorite?` |
| `Gtk::Box` | 2 | — | — | outer 8, inner 0 with the term as tooltip |
| `Gtk::Label` | 1 | — | — | term, `ellipsize = :end`, margins 8 |
| `Gtk::Button` | 1 | `flat`, `circular` | `clicked` | star/unstar, tooltip "Toggle Favorite" |

### `lib/wordbook/definition_view.rb` — repeater, one row per part of speech

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Gtk::ListBox` | 1 | `boxed-list-separate` | margins 12/12/8/12, `selection_mode = :none`, `show_separators = false`, vexpand |
| `Gtk::ListBoxRow` | per POS | `activatable` removed after `append` | margins 4, not focusable |
| `Gtk::Box` | per POS + per lemma + per pronunciation | — | vertical 12 (margins 12) / 8 / 4 |
| `Gtk::Label` | per POS | `pos-header` | selectable, markup, xalign 0 |

### `lib/wordbook/pronunciation_row.rb` — repeater, one per pronunciation group

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk::Box` | 2 | — | — | header 4, controls 2, both `valign = :center` |
| `Gtk::Label` (lemma) | 1 | `synset-header` | — | markup, selectable, hexpand, xalign 0 |
| `Gtk::Label` (IPA) | 0..1 | `dimmed` | — | only when the group has a non-empty IPA |
| `Gtk::Button` | 0..1 | `flat`, `circular` | `clicked` | `audio-volume-high-symbolic`, tooltip "Listen to Pronunciation"; passes `nil` ipa for a fallback transcription |

### `lib/wordbook/definition_row.rb` — repeater, one per synset

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk::Box` | 2 | — | — | 12 horizontal, 6 vertical hexpand |
| `Gtk::Label` (number) | 1 | `definition-number` | — | markup, `valign = :start`, `margin_top = 2`, size request 20×-1 |
| `Gtk::Label` (definition) | 1 | `definition` | `pressed`, `stopped` | wrap, selectable, extra menu |
| `Gtk::Label` (example) | 0..N | `example-text` | `pressed`, `stopped` | same shape |
| `Gtk::GestureClick` | 1 + N (controller) | — | `pressed`, `stopped` | one per label, from `double_click_gesture` |
| `Gtk::Separator` | between synsets | — | — | margins 8/8/32 |

### `lib/wordbook/relation_box.rb` — repeater, one per non-empty relation

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adwaita::WrapBox` *or* `Gtk::FlowBox` | 1 | — | — | conditional on `Adwaita.const_defined?(:WrapBox)`; line 4, child 6 |
| `Gtk::Label` | 1 | `relation-type` | — | "Synonyms:" / "Antonyms:" / "Similar to:" / "Also see:" |
| `Gtk::Button` | N | `lemma-button` | `clicked` | one chip per lemma |

### `lib/wordbook/search_completion.rb` — the completion popover

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk::Popover` | 1 | `completion-popover` | `closed` | no autohide, no arrow, `position = :bottom`, not focusable, **parented to the entry** |
| `Gtk::ScrolledWindow` | 1 | — | — | `propagate_natural_height`, frameless, not focusable |
| `Gtk::ListBox` | 1 | — | `row-activated` | `:single`, activate-on-single-click, not focusable |
| `Gtk::ListBoxRow` + `Gtk::Label` | ≤10 | — | — | activatable, selectable, not focusable; label ellipsized, margins 3/10 |
| `Gtk::EventControllerKey` | 1 (controller) | — | `key-pressed` | CAPTURE, on the entry |
| `Gtk::EventControllerFocus` | 1 (controller) | — | `enter`, `leave` | on the entry |
| `Gtk::GestureClick` | 1 (controller) | — | `pressed` | CAPTURE, on the window |

### `lib/wordbook/settings_dialog.rb` — preferences

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adwaita::PreferencesDialog` | 1 | — | — | 450×350, **title "Preferences"** (upstream sets none) |
| `Adwaita::PreferencesPage` | 1 | — | — | — |
| `Adwaita::PreferencesGroup` | 2 | — | — | "Appearance", "Behavior" |
| `Adwaita::SwitchRow` | 4 | — | `notify::active` ×4 | Force Dark Mode, Live Search, Double Click Search, Auto Paste on Launch |
| `Adwaita::ComboRow` | 1 | — | `notify::selected` | "Pronunciations Accent", `Gtk::StringList` of American/British English |

### `lib/wordbook/shortcuts_dialog.rb` — keyboard shortcuts

`Adwaita::ShortcutsDialog`, title "Keyboard Shortcuts", one
`Adwaita::ShortcutsSection` "General", 8 `Adwaita::ShortcutsItem`s built from a
loop (so the scan sees one). Items carry **literal accelerator strings**, not
action names.

### `lib/wordbook/error_dialog.rb`

`Adwaita::AlertDialog` (positional heading/body), one `dismiss` response
labelled "Dismiss", set as both default and close response. Two call sites in
`window.rb`: "Wordlist Loading" and "Invalid input".

### `lib/wordbook/about_dialog.rb`

`Adwaita::AboutDialog` subclass. Name, version, comments, developer,
translator-credits, GPL-3.0, website, issue URL, copyright, `add_link("Source
Code", …)` **and a second `add_link("Ruby Port", …)` upstream does not have**.

### `lib/wordbook/application.rb`

`Gtk::Application` (`:handles_command_line`). Signals `startup`,
`command-line`, `activate`, `shutdown`. Actions from the `APP_ACTIONS` loop:
`about`, `shortcuts`, `quit`. Accelerators from the `APP_ACCELS` hash — the
eight upstream binds, **plus `app.shortcuts` → `<Primary>question`, which
upstream never binds**. SIGINT/SIGTERM via `Signal.trap`.

### `lib/wordbook/style.rb`

The stylesheet as a frozen heredoc, loaded into a `Gtk::CssProvider` at
`PRIORITY_APPLICATION`. **Byte-identical to `data/resources/style.css`** — all
13 app classes plus the `listbox row.favorite-item` variants.

## Under-reported items the scan cannot see, recorded by reading

- **Repeaters.** `history_row`, `definition_view`, `definition_row`,
  `pronunciation_row`, `relation_box` are all one scan row and N widgets.
- **Actions from loops.** `WINDOW_ACTIONS` (8) and `APP_ACTIONS` (3) are built
  from `Gio::SimpleAction.new(name)` over a frozen array, so none of the eleven
  appears in the scan's `action` stream. Same for the 8 `ShortcutsItem`s.
- **Dynamic CSS.** `completion-entry` and `completion-active` are attached from
  `search_completion.rb`, not from the file that owns the entry;
  `favorite-item` is added and removed from `HistoryRow.apply_visuals`;
  `activatable` is *removed* in `definition_view.rb`; `devel` is conditional on
  `development_mode`.
- **Conditional widget substitution.** `Adwaita::Spinner`/`Gtk::Spinner` and
  `Adwaita::WrapBox`/`Gtk::FlowBox` are chosen at runtime, so both branches
  show in the port's widget stream and only one can ever exist.
- **Shared factories.** `DefinitionRow#searchable_label` is called 1+N times
  and `#double_click_gesture` once per label — one textual occurrence, many
  widgets and many controllers.
- **Accessibility.** Upstream attaches `accessibility { label: … }` to five
  widgets in `window.blp`. The scan has no stream for it and the port has no
  occurrence of it; it is recorded here so `component-parity` can carry it.
