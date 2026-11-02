# Component identification — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` (Python + blueprint) |
| Port | `ruby` @ `b5f105c` |
| Tool | `.claude/skills/component-identification/scripts/component-scan.sh` |
| Upstream rows | 155 |
| Port rows | 141 |

## Step 1 — the declarative UI

Upstream has three blueprint files and they *are* the inventory:

```
data/resources/ui/window.blp            template $WordbookWindow : Adw.ApplicationWindow
data/resources/ui/settings-window.blp   template $SettingsDialog : Adw.PreferencesDialog
data/resources/ui/shortcuts-dialog.blp  Adw.ShortcutsDialog shortcuts_dialog   (named root, not a template)
```

Two of the three roots are `template`; the shortcuts dialog is a **named
top-level object**, so matching `template` alone would have found two thirds of
the declarative UI. `window.blp` also carries a `menu app-menu` block, which is
a fourth unit with no widget of its own.

The port has **no** `.blp`/`.ui` files, by house-style design. Checked, not
assumed:

```
$ find . -name '*.blp' -o -name '*.ui' | grep -v '^./.git'
(nothing)
```

Notably the port builds `Adwaita::ShortcutsDialog` from Ruby, where
Commit-rb had to keep a `.ui` file for `GtkShortcutsWindow`. The Adwaita 1.9
dialog is constructible here; what is *not* reachable is its rows'
`action-name` property (`FINDINGS.md` 3).

## The unit list and the file mapping

Eleven upstream units. One upstream unit is split across a `.blp` and a `.py`
on the upstream side and sometimes across several Ruby files on the port side,
so the rows of every file in a row below are unioned before any axis is
compared.

| # | Unit | Upstream files | Port files |
|---|---|---|---|
| 1 | main window | `ui/window.blp` (template) + `wordbook/window.py` | `lib/wordbook/window.rb` |
| 2 | main menu | `ui/window.blp:4-42` (`menu app-menu`) | `lib/wordbook/main_menu.rb` |
| 3 | history sidebar | `ui/window.blp:61-145` + history half of `window.py` | `lib/wordbook/history_sidebar.rb`, `lib/wordbook/history_row.rb`, `lib/wordbook/history_object.rb` |
| 4 | definition view | `ui/window.blp:224-236` + `_populate_definitions` / `_create_*` in `window.py` | `lib/wordbook/definition_view.rb`, `definition_row.rb`, `relation_box.rb`, `pronunciation_row.rb` |
| 5 | preferences dialog | `ui/settings-window.blp` + `wordbook/settings_window.py` | `lib/wordbook/settings_dialog.rb` |
| 6 | shortcuts dialog | `ui/shortcuts-dialog.blp` | `lib/wordbook/shortcuts_dialog.rb` |
| 7 | about dialog | `on_about` in `wordbook/main.py` | `lib/wordbook/about_dialog.rb` |
| 8 | error alert | `_new_error` in `wordbook/window.py` | `lib/wordbook/error_dialog.rb` |
| 9 | search completion | `wordbook/search_completion.py` | `lib/wordbook/search_completion.rb` |
| 10 | application | `wordbook/main.py` + `wordbook/wordbook.in` | `lib/wordbook/application.rb`, `exe/wordbook` |
| 11 | shell search provider | `data/search_provider.in` + `.SearchProvider.ini` | `lib/wordbook/shell_search_provider.rb`, `exe/wordbook-search-provider` |

Non-widget upstream files and their port counterparts (no components, listed so
the mapping is complete): `base.py` → `base.rb` + `espeak.rb`; `database.py` →
`database_manager.rb`; `settings.py` → `settings.rb`; `utils.py` → `utils.rb`;
`constants.py` → `constants.rb`; `data/resources/style.css` → `style.rb`;
gettext imports → `translations.rb`.

**Upstream files with no port counterpart at all:**
`scripts/generate-wn-db.py`, `data/dev.mufeed.Wordbook.gschema.xml.in`,
`build-aux/flatpak/dev.mufeed.Wordbook.Devel.json`, `Wordbook.doap`,
`screenshots/light.png`, `screenshots/dark.png`,
`subprojects/wn` + `subprojects/blueprint-compiler.wrap`.
These are rows in `component-parity.md`, not footnotes here.

## Widget census

Upstream, by file (widget kind only; `Adw.ViewStackPage`, `Adw.ShortcutsItem`,
`Adw.ShortcutsSection`, `Adw.Breakpoint`, `Gtk.StringList` classify as `type`
against the GIR symbol table and are counted separately below):

| File | Widget | × |
|---|---|---:|
| `ui/window.blp` | `Adw.ApplicationWindow` | 1 |
| | `Adw.ToastOverlay` | 1 |
| | `Adw.OverlaySplitView` | 1 |
| | `Adw.ToolbarView` | 2 |
| | `Adw.HeaderBar` | 2 |
| | `Adw.WindowTitle` | 1 |
| | `Adw.ViewStack` | 2 |
| | `Adw.Clamp` | 2 |
| | `Adw.StatusPage` | 4 |
| | `Adw.Spinner` | 1 |
| | `Gtk.Box` | 1 |
| | `Gtk.Button` | 2 |
| | `Gtk.ToggleButton` | 2 |
| | `Gtk.Entry` | 1 |
| | `Gtk.MenuButton` | 1 |
| | `Gtk.ScrolledWindow` | 1 |
| | `Gtk.Viewport` | 1 |
| | `Gtk.ListBox` | 2 |
| `ui/settings-window.blp` | `Adw.PreferencesDialog` | 1 |
| | `Adw.PreferencesPage` | 1 |
| | `Adw.PreferencesGroup` | 2 |
| | `Adw.SwitchRow` | 4 |
| | `Adw.ComboRow` | 1 |
| `ui/shortcuts-dialog.blp` | `Adw.ShortcutsDialog` | 1 |
| `wordbook/window.py` | `Adw.AlertDialog` | 1 |
| | `Adw.WrapBox` | 1 |
| | `Gtk.Box` | 12 (per-call, not per-screen) |
| | `Gtk.Button` | 9 |
| | `Gtk.Label` | 9 |
| | `Gtk.ListBoxRow` | 4 |
| | `Gtk.Separator` | 2 |
| `wordbook/search_completion.py` | `Gtk.Popover` | 1 |
| | `Gtk.ScrolledWindow` | 1 |
| | `Gtk.ListBox` | 1 |
| | `Gtk.ListBoxRow` | 1 |
| | `Gtk.Label` | 1 |
| `wordbook/main.py` | `Adw.AboutDialog` | 1 |

Non-widget types that still carry behaviour, and therefore still have to exist:
`Adw.Breakpoint` ×1, `Adw.ViewStackPage` ×7, `Adw.ShortcutsSection` ×1,
`Adw.ShortcutsItem` ×8, `Gtk.StringList` ×1.

Controllers: `Gtk.EventControllerKey` ×2 (window template, completion),
`Gtk.EventControllerFocus` ×1, `Gtk.GestureClick` ×3 (completion ×1,
definition/example labels ×2).

The port's census is in the per-unit tables of `component-parity.md`, where it
is only meaningful side by side.

## CSS classes

Upstream applies 22 distinct classes. Declarative (`ui/window.blp`):
`flat` ×2, `navigation-sidebar`, `compact`, `suggested-action`,
`boxed-list-separate`, `pill`. Runtime (`window.py`, `search_completion.py`):
`devel`, `history-item`, `favorite-item`, `activatable` (removed, not added),
`circular` ×2, `dimmed`, `definition`, `definition-number`, `synset-header`,
`pos-header`, `example-text`, `relation-type`, `lemma-button`,
`completion-entry`, `completion-active`, `completion-popover`.

Thirteen of the 22 are defined in `data/resources/style.css`; the other nine
are Adwaita built-ins (`flat`, `circular`, `navigation-sidebar`, `compact`,
`suggested-action`, `boxed-list-separate`, `pill`, `dimmed`, `activatable`).
The port adds all 22 and its `style.rb` is byte-identical to upstream's CSS.

## Signals and actions

Signals upstream connects: `notify::is-active`, `key-pressed`, `activate-link`,
`clicked` ×6, `changed` ×2, `icon-press`, `items-changed`, `row-activated` ×2,
`pressed` ×3, `stopped` ×2, `button-clicked`, `closed`, `enter`, `leave`,
`notify::active` ×4, `notify::selected`, `activate` ×10 (`Gio::SimpleAction`),
plus one `bind_property` (`show-sidebar` ↔ `active`, bidirectional + sync).

Actions upstream installs: `app.about`, `app.quit`, `win.paste-search`,
`win.toggle-sidebar`, `win.toggle-menu`, `win.preferences`, `win.random-word`,
`win.search-selected`, `win.toggle-favorites`, `win.quit`.
Actions upstream *references* but never installs: `app.shortcuts` (the menu
item and the shortcuts row both target it; libadwaita auto-loads
`shortcuts-dialog.ui` from the resource base path instead).

Accelerators upstream binds: `<Primary>q` → `app.quit`; `<Primary>w` →
`win.quit`; `<Primary>s` → `win.search-selected`; `<Primary>r` →
`win.random-word`; `<Primary><Shift>v` → `win.paste-search`;
`<Primary>comma` → `win.preferences`; `F9` → `win.toggle-sidebar`;
`F10` → `win.toggle-menu`. Eight, and nothing for `app.shortcuts`.

Accessibility labels upstream sets in `window.blp`: five
(`favorites_filter_button`, `clear_history_button`, `search_button`,
`split_view_toggle_button`, `wordbook_menu_button`).

## What the scan could not see, and was read by hand

- every widget in units 3, 4, 8 and 10 — upstream builds them in Python at
  runtime, in loops, so the counts above are call sites and not screens;
- the port's `Adw.Breakpoint` ×2 and `Gtk.Window` ×1 rows: comment text and
  `Gtk::Window.set_default_icon_name`, not widgets;
- the port's `Adw.ApplicationWindow` ×3, `Adw.Spinner` ×3, `Adw.WrapBox` ×2,
  `Gtk.FlowBox` ×3, `Gtk.Spinner` ×2 rows: comment prose plus the two runtime
  fallback branches in `window.rb#new_spinner` and `relation_box.rb#new_wrap_box`.
  Only one branch of each is ever built;
- the port's `action win.toggle-favorites` row in `history_sidebar.rb`: that
  string appears only in a comment. The button carries no `action-name` — see
  `component-parity.md`, unit 3.
