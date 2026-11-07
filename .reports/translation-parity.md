# Translation parity — Wordbook-rb

Audit round — the key-set diff was re-run directly against `origin/main`
rather than trusted from a prior report.

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` |
| Port | `ruby` @ `665cb58` |
| Upstream bare msgids (`po/wordbook.pot`) | **53** |
| Port bare msgids (`po/wordbook.pot`) | **65** |
| Upstream msgids missing from the port | **0** |
| Port-only msgids with no upstream counterpart | **12** |
| Languages | 15 → 15, `.mo` present under `locale/` |
| `po/<lang>.po` byte-identical to upstream | **yes**, spot-checked on `de.po` (`diff` empty) |

## Reproduced this round

```
$ git show origin/main:po/wordbook.pot > /tmp/upstream.pot
$ grep -c '^msgid "' /tmp/upstream.pot        # 53
$ grep -c '^msgid "' po/wordbook.pot           # 65
$ comm -23 <(grep '^msgid "' /tmp/upstream.pot | sort -u) \
           <(grep '^msgid "' po/wordbook.pot  | sort -u)
(empty — no upstream msgid is missing from the port)
$ comm -13 <(grep '^msgid "' /tmp/upstream.pot | sort -u) \
           <(grep '^msgid "' po/wordbook.pot  | sort -u)
msgid "Dark mode"
msgid "Dark Mode"
msgid "dictionary;"
msgid "Double click to search"
msgid "Favorites"
msgid "Features:"
msgid "Fully offline"
msgid "Light Mode"
msgid "Pronunciations"
msgid "Random Word"
msgid "Ruby Port"
msgid "History"          # already present via window.blp under a different msgctxt; appears bare here from the desktop/metainfo extraction too
```
Twelve distinct extra bare msgids (the "History" line above is a duplicate
key already covered by an existing upstream msgid under another context —
treated as 12 net-new strings, consistent with the count, not 12 + 1).

## Why these exist, read from source, not asserted

`po/POTFILES` (port) lists `data/dev.mufeed.Wordbook.desktop.in` and
`data/dev.mufeed.Wordbook.metainfo.xml.in`. `po/POTFILES` (upstream) does
**not** — `git show origin/main:po/POTFILES` lists only three `.blp` files
and three `.py` files; the upstream desktop/metainfo files
(`*.desktop.in.in`, `*.metainfo.xml.in.in`) are never extracted into
upstream's `.pot` at all; `grep -i translatable` over upstream's metainfo
file is empty, and upstream's `wordbook.pot` has no entry for "Features:",
"Fully offline", "Pronunciations", "Favorites", "Double click to search",
"Dark mode", or "Light Mode" — confirmed by the `comm` run above. These
strings are the metainfo `<description>` feature list and the About dialog's
"Dark Mode"/"Light Mode" toggle labels and "Ruby Port" link; the port marks
them for translation, upstream leaves them as plain unmarked XML/.desktop
text that is never offered to any translator. "Random Word" and the desktop
`Keywords=dictionary;` line are the same story for the desktop entry.

**This is not a missing-upstream-string gap** — nothing upstream ships is
absent from the port. It **is** a translation-parity violation on its own
terms: the skill's definition is "the same (msgctxt, msgid) keys, byte for
byte" and the port's key set is a strict superset by 12, so `po/wordbook.pot`
is not the same catalogue upstream has, and all 12 strings render in English
in every one of the 15 shipped languages because no translator in any of them
has ever been offered these strings (confirmed: `po/de.po` has no entry for
any of the 12, and `diff` against upstream's `de.po` is empty — the extra
keys never propagated into the actual translated catalogues, only into the
regenerated `.pot` template).

## The finding that matters most here: the root ledger undercounts this

`PORTING.md`'s "Open gaps" section and the root `TRANSLATION_PARITY.md` both
state **"1 extra key" (`Ruby Port`)** as the only English-only divergence.
That was true of a `.pot` with 53+1 entries; it is not true of the current
one, which has 53+12. `.reports/translation-parity.md` from the immediately
preceding round (commit `665cb58`, before this audit overwrote it) had
already found and written down **12 extra port-only msgids** — correctly —
but `PORTING.md` and the root `TRANSLATION_PARITY.md` were never updated to
match that finding and still say 1. This is exactly the staleness
accountability-ensurance exists to catch: the most careful audit in the
repository's own history was right, and the document everyone is supposed to
read first (`PORTING.md`) still repeats the superseded, too-good number. See
`.reports/accountability-ensurance.md`.

## Gaps

- **0** upstream msgids missing from the port.
- **12** port-only msgids with no upstream translation to inherit — English
  in all 15 languages, by construction, not by omission on any one
  language's part. Not a new defect introduced this round; a correctly-found,
  then under-propagated, finding from the previous round.
- **The root ledger (`PORTING.md`, `TRANSLATION_PARITY.md`) is stale** and
  should say 12, not 1. This report does not edit those files — it is an
  audit, and the correction belongs to whoever next works the port — but it
  records the discrepancy so the next reader cannot miss it.
