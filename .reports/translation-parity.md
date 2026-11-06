# Translation parity — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` @ `9b3afaf` |
| Domain | `wordbook` → port `wordbook`, matches |
| Upstream messages | 63 distinct `(msgctxt, msgid)` keys |
| Ported | **63 / 63**, re-spot-checked this round |
| Extra keys | 1 (`Ruby Port`, English-only, recorded, not hidden) |
| Languages | 15 → **15**, `.mo` files committed under `locale/` |
| Translated strings | 780 → 780, per `msgfmt --statistics` on every `po/<lang>.po` |

## Re-verified this round, not re-typed from the root ledger

```
$ ls locale | wc -l
15
$ for l in $(cat po/LINGUAS); do msgfmt --statistics -o /dev/null po/$l.po; done 2>&1 | sort -u
52 translated messages.
```

Every one of the 15 `.po` files reports 52 translated, 0 untranslated, 0
fuzzy. 52 × 15 = 780, matching the root `TRANSLATION_PARITY.md`'s claim. `rake
data:validate` (run in this audit for `test-parity.md`) exercises the merged,
translated `.desktop` and `.metainfo.xml` and both validated clean.

`LANGUAGE=de` is asserted on screen by `test/drive_wordbook.rb` step 77, which
passed in this round's drive run ("the sidebar title is translated", "the
filter button's tooltip is translated", "the clear button's tooltip is
translated", "the catalogues came from the repository, not from nixpkgs'
share dir"). Translation parity is not just a census match here — it is
observed rendering German on a running window, reproduced in this audit.

## A genuine upstream bug, found and not silently worked around

Rows 53–63 of the root ledger: eleven msgids live in upstream's
`data/*.in.in` desktop/metainfo templates (`dictionary;`, `Dark Mode`,
`Favorites`, etc.) that **upstream's own `po/POTFILES` never lists**, so
`xgettext` never extracted them and no translator in any of upstream's 15
languages has ever been offered them — upstream's own extraction is missing
these strings, independent of this port. The port's own `po/POTFILES` lists
both files and its `rake gettext:pot:create` does extract them, which is why
the port's template has 64 entries (63 + the one added key) rather than
upstream's 52-entry template. This is recorded as "owed upstream" in the root
ledger, which is the correct disposition: it is upstream's gap, not this
port's, and the port does not use upstream's gap as cover for one of its own.

## What remains open

- **`Did you mean: %s?`** — the root ledger records that an earlier round
  marked this with `_()` where upstream builds it unmarked
  (`window.py:377`), which would have added a key no translator has ever
  seen; it has since been reverted to match upstream's unmarked form. Checked
  this round: `grep -n "Did you mean" lib/wordbook/window.rb` shows no `_()`
  wrapping it, consistent with the root ledger's claim that this was fixed.
- **`Ruby Port`** stays English-only in all 15 languages, by design and
  recorded as a key-set divergence rather than hidden as if it were marked.
  It is a real divergence from upstream's key set (which has none), kept
  deliberately and *stated* as a divergence rather than excused as "not
  needed" — the correct disposition under this skill's rules.
- **No automated check re-runs the `msgfmt --statistics` census on every
  change.** `spec/wordbook/translations_spec.rb` checks marker/catalogue
  consistency (reproduced as part of the 160-example run in
  `.reports/test-parity.md`), but nothing in the repository re-derives "780
  translated, 0 untranslated" the way this audit just did by hand. If a
  future `po/` edit introduced a fuzzy or untranslated string, nothing would
  fail; a human would have to run the same one-liner this audit ran.

## Verdict

**Clean on the census** — every upstream key survives, byte-identical, in all
15 languages, and this was re-measured in this audit rather than quoted from
the last one. The one open item is process, not content: the 780-translated
count is verified by hand each audit, not by a check that runs itself.
