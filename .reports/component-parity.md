# Component parity — Wordbook-rb

Audit round — re-derived, not carried forward.

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` |
| Port | `ruby` @ `665cb58` |
| Authoritative port ledger | `COMPONENT_PARITY.md` (root, 11 units) |
| Runtime gate reproduced this round | **215 of 215 checks passed, `DRIVE OK`** (`nix develop --command xvfb-run -a ruby test/drive_wordbook.rb`, run live for this audit) |

## What was re-checked against source, not against the ledger's prose

For each of the 11 units in `COMPONENT_PARITY.md`, the port file and the
upstream `.blp`/`.py` pair it claims were both opened this round:

| Unit | Port | Upstream | Spot-check |
|---|---|---|---|
| 1 Main window | `window.rb` | `window.blp` template + `window.py` | `Adw::Breakpoint` installed in both; same condition string `max-width: 550px` region — confirmed present in `window.rb` |
| 2 App menu | `main_menu.rb` | `window.blp:4-42` | menu items and their `action-name`s present in both; same count (6 items incl. separators) |
| 3 History sidebar | `history_sidebar.rb` | `window.blp:61-145` + `window.py` | filter button `action-name: "win.toggle-favorites"` present on both sides |
| 4 History row | `history_row.rb` | row builder in `window.py` | same per-row widgets (label, favourite toggle, delete button) |
| 5 Definition cluster | `definition_view.rb`/`definition_row.rb`/`pronunciation_row.rb`/`relation_box.rb` | `window.blp:224-236` + `_populate_definitions`/`_create_*` | four port files to upstream's one function cluster — same widget set per the union rule |
| 6 Search completion | `search_completion.rb` | `search_completion.py` | same signal (`notify::selected`) |
| 7 Preferences | `settings_dialog.rb` | `settings-window.blp` + `settings_window.py` | 5 rows both sides (dark mode, accent colour ×N, live TTS, pronunciations accent) |
| 8 Shortcuts | `shortcuts_dialog.rb` | `shortcuts-dialog.blp` | all 8 rows, each names its action, both sides |
| 9 Application | `application.rb`/`profile.rb`/`exe/wordbook` | `main.py` + `meson.build:40-50` | devel/stable app-id and icon switch confirmed live by the drive run ("the development profile is a second application" step, reproduced above) |
| 10 Search provider | `shell_search_provider.rb` + `exe/wordbook-search-provider` | `data/search_provider.in` | D-Bus object path and all 5 `SearchProvider2` methods — not re-run this round (see test-parity; `test/drive_search_provider_dbus.rb` is the live check and was not re-executed this pass, so this row is a carry-forward of the last audit, not a fresh reproduction) |
| 11 Error alert | `error_dialog.rb` | `_new_error` in `window.py` | same banner widget and dismiss action |

## The one axis this round adds beyond the root ledger: text

Component parity requires the fourth axis — "the same translatable strings" —
for every widget above, not just the first three (count/style/behaviour). The
root `COMPONENT_PARITY.md` and the units table above check widget/CSS/signal
parity per unit but defer string parity to the translation-parity report.
**That deferral is where this round's one real finding sits**: see
`.reports/translation-parity.md`. Twelve of the strings shown by units 1, 7
and 9 above (the main window's About dialog, the metainfo-sourced feature
list, the desktop entry) are marked for translation in the port with no
upstream msgid behind them — the widgets and signals are correct, but the
fourth axis (text) is not "the same msgid" for those strings, because no
upstream msgid exists for them to match. This does not change any of the 11
units' widget/CSS/behaviour verdicts above, all of which hold, but it means
unit 1 and unit 9 do not have unconditional four-axis parity — their count,
style and behaviour match, their *extra* text does not have an upstream
counterpart to be identical to.

## Gaps

**0 missing components.** No widget, dialog, menu item, action or signal
upstream builds is absent from the port on re-check this round. The only
open item is the text-axis finding above, which is a translation-parity
finding, not a missing widget, and is tracked there and in
accountability-ensurance (the root ledgers understate it).
