# Component identification — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` (Python/PyGObject + Blueprint + meson) |
| Port | `ruby` @ `0a35cd6` |
| Tool | `.claude/skills/component-identification/scripts/component-scan.sh`, symbol table of 1301 GIR rows |
| Upstream scan rows | 155 across 7 files |
| Port scan rows | 128 across 16 files |
| Read by hand | every row below; the scan was a lead, not a verdict |

## Step 1 — the declarative UI

Upstream has three blueprint files and they *are* the inventory:

```
data/resources/ui/window.blp            template $WordbookWindow : Adw.ApplicationWindow
data/resources/ui/settings-window.blp   template $SettingsDialog  : Adw.PreferencesDialog
data/resources/ui/shortcuts-dialog.blp  Adw.ShortcutsDialog shortcuts_dialog  (named root, not a template)
```

Two roots are `template`; the shortcuts dialog is a **named top-level object**,
so matching `template` alone finds two thirds of the declarative UI.
`window.blp:4-42` also carries a `menu app-menu` block — a fourth unit with no
widget of its own, all lowercase keywords, so the scan produces nothing for it.

The port has no `.blp`/`.ui` files. Checked, not assumed:

```
$ find . -name '*.blp' -o -name '*.ui' | grep -v '^./.git'
(nothing)
```

Unlike Commit-rb, this port needs none: `Adwaita::ShortcutsDialog`,
`Adwaita::ShortcutsItem#action_name=` and `Adwaita::Breakpoint` are all
reachable from these bindings (`FINDINGS.md` 2 and 3, both now closed). The one
place it reaches for `Gtk::Builder` is the five `<accessibility>` blocks, whose
introspected setter is unimplemented (`FINDINGS.md` 10) — `Utils.accessible`
builds a one-object `<interface>` snippet instead. That is a declarative
fragment inside Ruby, not a `.ui` file, and it is listed here so the next scan
does not read it as one.

## The unit list and the file mapping

Eleven upstream units. Rows of every file on the left are unioned before any
axis is compared.

| # | Unit | Upstream files | Port files |
|---|---|---|---|
| 1 | main window | `ui/window.blp` (template) + `wordbook/window.py` | `lib/wordbook/window.rb` |
| 2 | main menu | `ui/window.blp:4-42` (`menu app-menu`) | `lib/wordbook/main_menu.rb` |
| 3 | history sidebar | `ui/window.blp:61-145` + history half of `window.py` | `history_sidebar.rb`, `history_row.rb`, `history_object.rb` |
| 4 | definition view | `ui/window.blp:224-236` + `_populate_definitions` / `_create_*` | `definition_view.rb`, `definition_row.rb`, `relation_box.rb`, `pronunciation_row.rb` |
| 5 | preferences dialog | `ui/settings-window.blp` + `wordbook/settings_window.py` | `settings_dialog.rb` |
| 6 | shortcuts dialog | `ui/shortcuts-dialog.blp` | `shortcuts_dialog.rb` |
| 7 | about dialog | `on_about` in `wordbook/main.py` | `about_dialog.rb` |
| 8 | error alert | `_new_error` in `wordbook/window.py` | `error_dialog.rb` |
| 9 | search completion | `wordbook/search_completion.py` | `search_completion.rb` |
| 10 | application | `wordbook/main.py` + `wordbook/wordbook.in` | `application.rb`, `exe/wordbook` |
| 11 | shell search provider | `data/search_provider.in` + `.SearchProvider.ini` | `shell_search_provider.rb`, `exe/wordbook-search-provider` |

**Eleven, not ten.** `COMPONENT_PARITY.md` at the root counts ten and folds the
about dialog into unit 9; the error alert (unit 8 here) has no row in it at all.
See `component-parity.md`, gap 10.

Non-widget upstream files and their counterparts, so the mapping is complete:
`base.py` → `base.rb` + `espeak.rb`; `database.py` → `database_manager.rb`;
`settings.py` → `settings.rb`; `utils.py` → `utils.rb`; `constants.py` →
`constants.rb`; `data/resources/style.css` → `style.rb`; the gettext imports →
`translations.rb`.

**Upstream files with no port counterpart at all** — rows in
`component-parity.md`, not footnotes here: `scripts/generate-wn-db.py`,
`data/dev.mufeed.Wordbook.gschema.xml.in`,
`build-aux/flatpak/dev.mufeed.Wordbook.Devel.json`, `scripts/flatpak-wheel-gen.py`,
`Wordbook.doap`, `screenshots/light.png`, `screenshots/dark.png`,
`meson_options.txt`'s `profile=development` wiring, `subprojects/wn`,
`subprojects/blueprint-compiler.wrap`,
`data/resources/resources.gresource.xml`.

## Widget census — upstream

Per-call-site counts; `Adw.Breakpoint`, `Adw.ViewStackPage`,
`Adw.ShortcutsItem`, `Adw.ShortcutsSection` and `Gtk.StringList` classify as
`type` against the symbol table and are listed separately.

| File | Widget | × |
|---|---|---:|
| `ui/window.blp` | `Adw.ApplicationWindow` | 1 |
| | `Adw.ToastOverlay` | 1 |
| | `Adw.OverlaySplitView` (min/max sidebar 200) | 1 |
| | `Adw.ToolbarView` | 2 |
| | `Adw.HeaderBar` | 2 |
| | `Adw.WindowTitle` | 1 |
| | `Adw.ViewStack` | 2 |
| | `Adw.Clamp` (thresholds 300, 500) | 2 |
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
| | `Gtk.Box` | 12 |
| | `Gtk.Button` | 9 |
| | `Gtk.Label` | 9 |
| | `Gtk.ListBoxRow` | 4 |
| | `Gtk.Separator` | 2 |
| `wordbook/search_completion.py` | `Gtk.Popover`, `Gtk.ScrolledWindow`, `Gtk.ListBox`, `Gtk.ListBoxRow`, `Gtk.Label` | 1 each |
| `wordbook/main.py` | `Adw.AboutDialog` | 1 |

Non-widget types carrying behaviour, which therefore still have to exist:
`Adw.Breakpoint` ×1, `Adw.ViewStackPage` ×7, `Adw.ShortcutsSection` ×1,
`Adw.ShortcutsItem` ×8, `Gtk.StringList` ×1.

Controllers: `Gtk.EventControllerKey` ×2 (window, completion),
`Gtk.EventControllerFocus` ×1, `Gtk.GestureClick` ×3 (completion ×1,
definition and example labels ×2).

Every widget in units 3, 4, 8 and 10 is built in Python at runtime, much of it
in loops, so those rows are **repeaters**: one scan row, N widgets on screen,
driven by the synset / history collection.

## Widget census — port

Only meaningful side by side, so the counts live in `component-parity.md`.
What the scan over-reported here, struck by reading:

- `Adw.ApplicationWindow` ×2, `Adw.Breakpoint` ×2, `Adw.WrapBox` ×2,
  `Adw.ShortcutsDialog` ×2, `Adw.AlertDialog` ×2, `Adw.Spinner` ×2 — the second
  occurrence of each is comment prose naming the upstream widget, not a
  construction.
- `Gtk.ApplicationWindow` ×1 in `window.rb` — a comment recording what the
  class used to be. The window is now `Adwaita::ApplicationWindow`.
- `Gtk.Window` ×1 — `Gtk::Window.set_default_icon_name`, not a widget.
- `Gtk.Builder`, `Gtk.CssProvider`, `Gtk.StyleContext`, `Gtk.StyleProvider` —
  the accessibility snippet and the stylesheet installer; `type`, not widgets.
- `Gtk.Widget` ×5 upstream — PyGObject template plumbing.

What the scan under-reported here, found by reading:

- `definition_row.rb:101` and `pronunciation_row.rb:71` attach their CSS class
  from a **variable** (`css_class`, `@css_class`), so `definition`,
  `example-text` and `synset-header` produce no `css` row on the port side
  while being attached correctly. Verified at the call sites
  (`definition_row.rb:78,81`).
- `search_completion.rb:50,393` attach `completion-entry` and
  `completion-active` through `ENTRY_CLASS` / `ENTRY_ACTIVE_CLASS`. Upstream
  does the same through `self._ENTRY_CLASS`, so neither side produces a row.
- Both action streams are near-empty because every action name is built in a
  loop: `APP_ACTIONS` (`application.rb:66`) and `WINDOW_ACTIONS`
  (`window.rb:78-87`) are read by hand below.
- `main_menu.rb` produces **no scan row at all** — its six items are a table of
  `N_()` labels and action strings. Counted by hand: 6.

## CSS classes

Upstream attaches 22 distinct classes. Declarative (`ui/window.blp`): `flat`
×2, `navigation-sidebar`, `compact`, `suggested-action`,
`boxed-list-separate`, `pill`. Runtime: `devel`, `history-item`,
`favorite-item`, `activatable` (removed, not added), `circular` ×2, `dimmed`,
`definition`, `definition-number`, `synset-header`, `pos-header`,
`example-text`, `relation-type`, `lemma-button`, `completion-entry`,
`completion-active`, `completion-popover`.

Thirteen are defined in `data/resources/style.css`; the other nine are Adwaita
or GTK built-ins and need no rule in either stylesheet. The port attaches all
22 and `lib/wordbook/style.rb`'s heredoc is **byte-identical** to upstream's
100-line `style.css` — extracted and diffed, no output.

## Signals and actions

Signals upstream connects: `notify::is-active`, `key-pressed` ×2,
`activate-link`, `clicked` ×6, `changed` ×2, `icon-press`, `items-changed`,
`row-activated` ×2, `pressed` ×3, `stopped` ×2, `button-clicked`, `closed`,
`enter`, `leave`, `notify::active` ×4, `notify::selected`, `activate` ×10 (the
ten `Gio.SimpleAction`s), plus one `bind_property`
(`show-sidebar` ↔ toggle `active`, bidirectional + sync-create).

Actions upstream installs: `app.about`, `app.quit` (`main.py:175-181`);
`win.paste-search`, `win.toggle-sidebar`, `win.toggle-menu`, `win.preferences`,
`win.random-word`, `win.search-selected`, `win.toggle-favorites`, `win.quit`
(`window.py:187-220`). Ten.

Actions upstream *references* but never installs: `app.shortcuts` — both the
menu item and the shortcuts row target it, and libadwaita auto-loads
`shortcuts-dialog.ui` from the resource base path instead.

Accelerators upstream binds (`main.py:183-190`): eight — `<Primary>q`→`app.quit`,
`<Primary>w`→`win.quit`, `<Primary>s`→`win.search-selected`,
`<Primary>r`→`win.random-word`, `<Primary><Shift>v`→`win.paste-search`,
`<Primary>comma`→`win.preferences`, `F9`→`win.toggle-sidebar`,
`F10`→`win.toggle-menu`. Nothing for `app.shortcuts`.

Accessibility labels upstream sets in `window.blp`: five, on
`favorites_filter_button`, `clear_history_button`, `search_button`,
`split_view_toggle_button` and `wordbook_menu_button`. All five are built in
the port (`history_sidebar.rb:174,182`, `window.rb:898,907,914`).

`action-name` properties upstream puts on widgets: one on
`favorites_filter_button` (`window.blp:78`), eight on the shortcuts rows
(`shortcuts-dialog.blp:10,15,20,25,30,35,40,45`). The port sets the eight
(`shortcuts_dialog.rb:62`) and not the one — `component-parity.md`, gap 1.

## What the runtime told the inventory that no scan could

The port is driven headlessly (`test/drive_wordbook.rb`, 198 checks, re-run for
this audit, `DRIVE OK`). Line coverage over `lib/` under that run, measured
with Ruby's `Coverage`, is **1833/2038 = 89.9 %** across **26 files, every one
of which is entered**. So no component is wholly unexercised. Three files are
exercised far less than the rest, and in each case the uncovered block is a
whole behaviour:

| File | Covered | Never executed |
|---|---|---|
| `database_manager.rb` | 37/68 | the entire extraction path: `extract_database`, `decompress`, the `zstd` invocation, the atomic rename, `cleanup_old_versions`, `old_version_dirs`, and the *success* branch of `find_compressed_db` |
| `shell_search_provider.rb` | 57/90 | the entire D-Bus surface: `run`, `register`, `handle_method_call`, `activate_result`'s spawn, and the `GLib::Variant` builders `string_array` / `metas_variant` / `quote` |
| `espeak.rb` | 46/70 | the timeout kill path, the missing-binary and non-zero-exit paths, the LRU eviction, and the whole `--version` / `--info` path |

Those three blocks are where `component-parity.md`'s unverified rows are, and
they are listed here because an inventory that records a component as present
without recording whether anything ever entered it is the inventory that makes
a port look finished.
