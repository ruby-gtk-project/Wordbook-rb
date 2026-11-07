# Accountability ensurance — Wordbook-rb

| | |
|---|---|
| Port | `ruby` @ `e3c6135` |
| Scanned | `lib/`, `exe/`, `.reports/*.md`, `PORTING.md` |
| Patterns | `TODO`, `FIXME`, `not implemented`, `for now`, `in a future` |

## The scan, re-run this round

```
$ grep -rn 'TODO\|FIXME\|not implemented\|for now\|in a future' lib exe PORTING.md
(no matches)
```

No excuse pattern appears anywhere in the shipped code or in `PORTING.md`.
`FINDINGS.md` quotes one `NotImplementedError: TODO: in Ruby -> ...` string,
but it is a *literal Ruby binding exception message*, quoted as evidence of a
binding defect, not an excuse written by the porting agent — correctly
distinguished from a real "TODO" by the prior round and re-confirmed here by
reading the surrounding paragraph.

## Green claims checked against what actually executed this round

This is the part of the skill that matters most and is where this round's
work concentrated, rather than re-running the grep alone:

| Claim | Backed by an execution this round? |
|---|---|
| "160 examples, 0 failures" | **yes** — `nix develop --command xvfb-run -a rspec -O /dev/null -Ilib spec` re-run, exit 0, log read in full |
| "215 of 215 checks passed, DRIVE OK" | **yes** — `nix develop --command xvfb-run -a ruby test/drive_wordbook.rb` re-run, log read in full |
| "222 checks passed... 11 components" (this round's stated runtime gate) | **no** — not reproduced; the actual re-run gives 215, not 222. This is flagged in `component-identification.md` and `component-parity.md` and is **the most important finding in this audit**: a gate number that does not reproduce from the checkout it describes is a false-green risk by definition, whether or not the underlying app is healthy. It is reported here rather than quietly reconciled, because reconciling it would require guessing which of the harness's checks were run under different conditions (e.g. counting steps instead of assertions, or a different environment with network access), and a guess is not a verification. |
| "every upstream msgid survived" | **yes** — `comm -23` re-run this round against `origin/main`'s actual `.pot`, empty diff |
| "upstream's 3 tests ported" | **not re-run this round** — carried forward from the prior audit, since `origin/main`'s `data/` tree has not moved; flagged as a carry-forward in `test-parity.md`, not hidden |
| "per-language msgfmt statistics (780 strings / 15 languages)" | **not re-run this round** — carried forward, flagged in `translation-parity.md` |
| flatpak manifest "builds" | **no** — `component-parity.md` and the root `COMPONENT_PARITY.md` both already say this is proven syntactically valid JSON, not proven to build (no privileged container, no `org.gnome.Sdk` fetched in this environment). Correctly labeled as unproven in the source documents, not claimed as green. |
| D-Bus search-provider surface, real WordNet-query behaviour, search-threading timers | **no check, this round or any prior one, exercises these** — correctly labeled "not covered" in `TEST_PARITY.md` and re-confirmed by reading the driver and spec files directly. This is the kind of gap the skill exists to catch: it is accurately disclosed in the existing docs, so it is not a false green, but it is still an open, real gap and is carried into this round's `test-parity.md` and `component-parity.md` rather than dropped.

## Conclusion

No excuse language was found in code or docs. The one real accountability
finding this round surfaces is the unreconciled runtime-gate count (222
claimed vs. 215 reproduced) — every other claim checked either reproduced
cleanly or was explicitly marked as a carry-forward rather than silently
re-asserted. A claim that does not reproduce is reported as a gap here, not
smoothed over, per the task's framing that a false green is the most serious
finding this audit can make.
