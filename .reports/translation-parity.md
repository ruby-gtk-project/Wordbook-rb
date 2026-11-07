# Translation parity — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` @ `e3c6135` |
| Domain | `wordbook` → port `wordbook`, matches |
| Upstream `.pot` msgids | 53 (`git show origin/main:po/wordbook.pot`, re-extracted this round) |
| Port `.pot` msgids | 65 — superset, re-extracted this round |
| Missing upstream msgids | **0** — `comm -23` of the sorted id sets is empty, verified directly this round, not re-quoted from the root ledger |
| Extra port-only msgids | 12 (`Dark mode`/`Dark Mode`, `dictionary;`, `Double click to search`, `Favorites`, `Features:`, `Fully offline`, `Light Mode`, `Pronunciations`, `Random Word`, `Ruby Port`, and two more from the same block) — all English-side additions the port carries for its own About/landing content, not hidden |
| Languages | 15 → **15**, `.mo` files present under `locale/` |

## What this round re-verified directly

```
$ git show origin/main:po/wordbook.pot > /tmp/upstream.pot
$ grep -c '^msgid "' /tmp/upstream.pot        # 53
$ grep -c '^msgid "' po/wordbook.pot           # 65
$ comm -23 <(grep '^msgid "' /tmp/upstream.pot | sort) \
           <(grep '^msgid "' po/wordbook.pot | sort)
# (empty)
```

Every upstream msgid is present in the port's `.pot` byte for byte on the
`msgid "..."` line. This matches the root ledger's claim (which counts
`(msgctxt, msgid)` pairs at 63 rather than bare msgids at 53 — the two counts
are not directly comparable, since a msgid used under two different
`msgctxt`s counts once here and twice there; neither counting shows a missing
upstream string).

## Not independently re-verified this round

- Per-language translated-string counts (`msgfmt --statistics` per catalogue)
  — re-reading the root ledger's 780-strings-across-15-languages figure
  rather than re-running all 15 `msgfmt` invocations this pass. No `po/*.po`
  file changed since the last audit (`git diff 9b3afaf -- po/` is empty), so
  this is a low-risk carry-forward, but it is a carry-forward, not a
  reproduction, and is recorded as such rather than silently re-asserted as
  freshly checked.
- `msgctxt` distinctions (`p_("shortcut window", …)` etc.) — re-read
  `spec/wordbook/translations_spec.rb`'s intent (10 examples, all passed in
  this round's suite run) rather than manually re-diffing every `msgctxt`.

## Conclusion

No upstream msgid is lost. The port adds English-only strings for content
upstream doesn't have (an About page crediting the Ruby port, a few
marketing-style landing strings); none of these shadow or replace an upstream
key. The per-language statistics claim is inherited from a prior round and
not re-measured here — flagged rather than silently repeated as new work.
