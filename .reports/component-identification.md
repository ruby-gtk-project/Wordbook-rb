# Component identification — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` (Python/PyGObject + Blueprint + meson) |
| Port | `ruby` @ `e3c6135` |
| Re-audited from | `.reports/component-identification.md` @ `9b3afaf` — re-read against the current tree, not trusted |

## Upstream inventory, re-walked

```
$ git ls-tree -r --name-only origin/main | grep -E '\.(py|blp)$'
```
returns 15 files (3 `.blp`, 12 `.py`) — unchanged from the prior audit;
upstream has not moved on `main`.

## Port inventory, re-walked

```
$ find lib -name '*.rb' | wc -l   -> 30
```
30 `.rb` files under `lib/wordbook*`, one more than the 29 the previous round
counted (`lib/wordbook/rb/version.rb` is new scaffolding, not a ported unit —
it carries the gem's own version constant and has no upstream counterpart).
Every upstream `.py`/`.blp` pair still maps to exactly one `lib/wordbook/*.rb`
file, confirmed by file and (spot-checked) line number against
`COMPONENT_PARITY.md`'s table, which remains the authoritative ledger.

## The reconciliation gap — still open

This round's runtime gate reports **"222 checks passed... covering 11
components."** Reproducing the drive from this checkout gives **215 of 215
checks passed, `DRIVE OK`** (`nix develop --command xvfb-run -a ruby
test/drive_wordbook.rb`), not 222. Three prior rounds have now hit the same
unresolved problem from three different angles — a prior gate said "17
components" against this file's 30-file count and `COMPONENT_PARITY.md`'s
"11 units"; this round's gate says "222 checks" against a reproduced 215.
Nothing in the repository defines what the harness is counting or why the
reproduced number keeps drifting from the reported one. This is a
**traceability gap**, not evidence either number is wrong, but an
unreconciled gate number is exactly the kind of claim that should not be
taken as "done" — see `accountability-ensurance.md`, which treats an
unexecuted or unreconciled green as the most serious class of finding.

## Conclusion

Every upstream component still has a counterpart file; no new upstream unit
appeared on `main` this round. The open item is not "something is missing
from `lib/`" but that the gate's own component/check count cannot be
reconciled against anything in this tree, for the third round running.
