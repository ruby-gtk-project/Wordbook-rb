# Component identification — the canonical unit ledger

Three countings of "how many components this port has" have been floating
around this repo's audit trail without ever being joined:

| Counting | Number | Source |
|---|---:|---|
| UI units in `COMPONENT_PARITY.md` | **11** | one row per upstream-identified screen/dialog/subsystem |
| Files under `lib/` | **30** | `find lib -name '*.rb' \| wc -l` |
| "Components" reported by the external runtime gate | **17** | a harness step outside this repository; its source is not in this checkout, so the number can only be checked from the outside |

This file is the canonical per-file ledger the earlier audits said was
missing. It fixes the first two numbers against each other with file-level
detail, and says plainly what is and is not knowable about the third from
inside this repo.

## The 11 units, resolved to files

Each `COMPONENT_PARITY.md` unit is one or more `lib/` files:

| Unit | Files | Count |
|---|---|---:|
| 1 — main window | `window.rb` | 1 |
| 2 — `menu app-menu` | `main_menu.rb` | 1 |
| 3 — history sidebar | `history_sidebar.rb` | 1 |
| 4 — history row | `history_row.rb` | 1 |
| 5 — definition view, row, pronunciation header, relation box | `definition_view.rb`, `definition_row.rb`, `pronunciation_row.rb`, `relation_box.rb` | 4 |
| 6 — search completion popover | `search_completion.rb` | 1 |
| 7 — preferences | `settings_dialog.rb` | 1 |
| 8 — keyboard shortcuts | `shortcuts_dialog.rb` | 1 |
| 9 — the application | `application.rb`, `about_dialog.rb` | 2 |
| 10 — GNOME Shell search provider | `shell_search_provider.rb` | 1 |
| 11 — invalid-input alert | `error_dialog.rb` | 1 |
| **Total, 11 units** | | **15 files** |

## The other 15 files

The remaining `30 - 15 = 15` files are backend/support code that no
`COMPONENT_PARITY.md` row treats as its own on-screen unit, because none of
them puts a widget on screen by itself — they are read by one or more of the
15 files above:

```
base.rb               database_builder.rb    database_manager.rb
espeak.rb              history_object.rb      lexicon_download.rb
lmf_reader.rb          profile.rb             settings.rb
style.rb               translations.rb        utils.rb
constants.rb           wordbook.rb (top level) rb/version.rb
```

`15 (unit files) + 15 (support files) = 30`, which reconciles the 11-unit
count against the 30-file count exactly: every unit file is a `lib/` file,
every support file is accounted for, and no file is claimed by two units.

## The gate's 17 — what can and cannot be said from here

The external harness's "17 components, 0 failed" cannot be reconstructed from
inside this checkout, because the step that emits it runs outside this
repository and its source is not available to audit. What can be said:

- 17 does not equal either number above (11 units, 30 files), so it is
  counting something between the two — plausibly the widget-bearing files
  alone, which this ledger separates out: `window.rb`, `main_menu.rb`,
  `history_sidebar.rb`, `history_row.rb`, `definition_view.rb`,
  `definition_row.rb`, `pronunciation_row.rb`, `relation_box.rb`,
  `search_completion.rb`, `settings_dialog.rb`, `shortcuts_dialog.rb`,
  `about_dialog.rb`, `error_dialog.rb`, `application.rb`, `style.rb` — 15 — is
  the closest subset this repo can name, two short of 17.
- Candidates for the missing two, if the gate also counts non-dialog pieces
  this ledger treats as support rather than a unit: `shell_search_provider.rb`
  (its own D-Bus-facing surface, separate from the window it shares `window.py`
  with) and `main_menu.rb`'s `Gio::Menu` tree (counted once here as the one
  file, but it is itself a composite of six items the gate may walk
  separately). Both are guesses; neither is confirmed.
- This is recorded as a **traceability gap**, not a missing feature: every
  upstream component has a `lib/` counterpart (see `COMPONENT_PARITY.md`),
  and the open question is only whether the gate's own count can be checked
  against the port's, not whether the port is complete.

**For this to close instead of being re-guessed every round**: the harness
step that reports "17 components" needs to name its 17 explicitly (one line
per component it counted), the way this file now names its 11 and its 30. The
fix belongs in the harness, not in a guess made from this side of it.
