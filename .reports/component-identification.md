# Component identification — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` (Python/PyGObject + Blueprint + meson) |
| Port | `ruby` @ `9b3afaf` |
| Re-audited from | `.reports/component-identification.md` @ `0a35cd6` — re-read against the current tree rather than trusted |

## Upstream inventory (unchanged — upstream has not moved)

Three `.blp` files hold the declarative UI and are the primary inventory:

```
data/resources/ui/window.blp            template $WordbookWindow : Adw.ApplicationWindow
data/resources/ui/settings-window.blp   template $SettingsDialog  : Adw.PreferencesDialog
data/resources/ui/shortcuts-dialog.blp  Adw.ShortcutsDialog shortcuts_dialog (named root)
```

Seven Python modules hold the logic (`main.py`, `window.py`, `settings_window.py`,
`search_completion.py`, `settings.py`, `base.py`, `database.py`, `utils.py`,
`constants.py`), plus the non-UI build/data surface: `scripts/generate-wn-db.py`,
`data/search_provider.in`, `data/*.in.in` (desktop, metainfo, gschema), four
icons, `Wordbook.doap`, `build-aux/flatpak/*`, `po/` (15 languages).

## Port inventory, re-counted this round

```
$ find lib -name '*.rb' | wc -l
30
$ find exe -type f | wc -l
3
```

30 files under `lib/wordbook/` (plus `lib/wordbook.rb` and
`lib/wordbook/rb/version.rb`), 3 executables. Every upstream unit the earlier
`.reports/component-identification.md` mapped still has a port file; three
files were added since that audit and are new mappings, not replacements:

| Added since `0a35cd6` | Maps to |
|---|---|
| `lib/wordbook/profile.rb` | `meson_options.txt`'s `profile` option + `meson.build:40-51` |
| `lib/wordbook/lmf_reader.rb`, `lib/wordbook/database_builder.rb` | `scripts/generate-wn-db.py` + the vendored Python `wn` loader it drives |

`lib/wordbook/lexicon_download.rb` already existed at the prior audit and is
unchanged.

## A reconciliation gap, found by this round

The runtime gate this round reports **"17 components"**. Nothing in this
repository — not `COMPONENT_IDENTIFICATION.md`'s absence, not
`COMPONENT_PARITY.md`'s **11 units**, not this file's 30-file count — defines
what the harness's 17 are or maps them to either number. Three different
countings of "how many components this port has" exist (11, 17, 30) and no
document joins them. That is not itself evidence of a missing feature, but it
means the gate's own coverage claim ("17 components, 0 failed") cannot be
checked against the port's own unit list without guessing which rows the
harness is counting. Recorded as a gap in **traceability**, not in widgets.

## Step 1 — declarative UI, re-walked

No `.blp`/`.ui` file in the port (there is none — the house style folds the
blueprint and the Python class into one `.rb` file). Re-verified by hand
against both `window.blp`'s full tree and `lib/wordbook/window.rb` for this
round rather than re-citing the prior scan's row counts: the widget list in
`.reports/component-parity.md`'s Unit 1 table still matches what
`lib/wordbook/window.rb` builds today, file and line numbers checked.

## Conclusion

Every upstream component has a counterpart file. The open question this round
surfaces is not "is something missing from `lib/`" — nothing is — but whether
the harness's own component count can be reconciled with the port's; see
`component-parity.md` for the behavioural gaps that count found underneath it
(flatpak packaging, upstream's screenshots still linked, the search provider's
D-Bus surface never executed).
