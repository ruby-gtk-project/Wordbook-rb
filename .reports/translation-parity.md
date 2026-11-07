# Translation parity — Wordbook-rb

Audit round — the key-set diff was re-run directly against `origin/main`.

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` |
| Port | `ruby` @ `d3c3f60` |
| Upstream bare msgids (`po/wordbook.pot`) | **53** |
| Port bare msgids (`po/wordbook.pot`) | **65** |
| Upstream msgids missing from the port | **0** |
| Port-only msgids with no upstream counterpart | **12** (unchanged from the prior round) |
| Languages | 15 → 15, `.mo` present under `locale/` |
| `po/<lang>.po` byte-identical to upstream | **yes**, spot-checked on `de.po` (`diff` empty) |

## Reproduced this round

```
$ git show origin/main:po/wordbook.pot > /tmp/upstream.pot
$ grep -c '^msgid "' /tmp/upstream.pot        # 53
$ grep -c '^msgid "' po/wordbook.pot           # 65
```
Both counts identical to the prior two audit rounds; `origin/main` has not
moved (still `4b43165`), and `po/wordbook.pot` has not been regenerated
since. This round's `comm` diff reproduces the same 12 port-only msgids as
before: `Dark mode`, `Dark Mode`, `dictionary;`, `Double click to search`,
`Favorites`, `Features:`, `Fully offline`, `Light Mode`, `Pronunciations`,
`Random Word`, `Ruby Port`, bare `History`.

## The one change since the last audit: the root ledger was corrected

The previous round's `translation-parity.md` and `accountability-ensurance.md`
found that `PORTING.md` and `TRANSLATION_PARITY.md` still said "1 extra key"
when the real count was 12. That has since been fixed on this branch
(commit `d3c3f60`, "Correct stale translation-extra and driver-check counts
in root ledgers"): `PORTING.md`'s header table and "Open gaps" section, and
`TRANSLATION_PARITY.md`'s `## Extra` section, now both say **12** and list
all twelve strings with their site and cause. Checked by reading both files
directly this round, not assumed from the commit message. **This specific
staleness is resolved.**

## Why these exist, re-confirmed from source

`po/POTFILES` (port) lists `data/dev.mufeed.Wordbook.desktop.in` and
`data/dev.mufeed.Wordbook.metainfo.xml.in`; `git show origin/main:po/POTFILES`
lists only three `.blp` and three `.py` files — upstream never extracts its
desktop/metainfo files into its `.pot` at all. The 11 non-`Ruby Port` extras
are the metainfo `<description>` feature list and the About dialog's mode
labels; `Ruby Port` is the deliberate about-dialog repo link with no
upstream string to diverge from.

**Not a missing-upstream-string gap** — all 53 upstream msgids are present
and translated in all 15 catalogues (`de.po` byte-identical to upstream's).
**Is** a translation-parity violation on the skill's own terms: the key set
is a strict superset by 12, and those 12 render in English in every shipped
language because no translator in any of them has ever been offered them.

## Gaps

- **0** upstream msgids missing from the port.
- **12** port-only msgids with no upstream translation to inherit — English
  in all 15 languages, unchanged from the prior round, now correctly
  reflected in the root ledgers as well as here.
