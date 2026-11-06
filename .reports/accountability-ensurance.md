# Accountability ensurance — Wordbook-rb

| | |
|---|---|
| Port | `ruby` @ `9b3afaf` |
| Scanned | `lib/`, `exe/`, `COMPONENT_PARITY.md`, `TEST_PARITY.md`, `TRANSLATION_PARITY.md`, `FINDINGS.md`, `PORTING.md`, `.reports/*.md` |
| Tool | `.claude/skills/accountability-ensurance/scripts/find-excuses.sh` |

## The scan

```
$ bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh .
```

Every hit returned is inside `.reports/*.md` files that are themselves *about*
excuses — the skill's own exemption for a document stating the rule, and for
this round's own prior reports quoting the construction they are warning
against (e.g. `.reports/accountability-ensurance.md` quoting "by design" as an
example of a hit). **Zero hits in `lib/`, `exe/`, or any of the four root
ledgers** (`COMPONENT_PARITY.md`, `TEST_PARITY.md`, `TRANSLATION_PARITY.md`,
`FINDINGS.md`) and zero in `PORTING.md`.

Separately grepped for the task's own list, case-insensitively, over
`lib/`, `exe/`, `.reports/`, and `PORTING.md`:

```
$ grep -rin 'TODO\|FIXME\|not implemented\|for now\|in a future' lib exe PORTING.md
(no matches)
```

The only "TODO" anywhere in the tracked docs is inside a quoted Ruby
exception message in `FINDINGS.md` 10 (`NotImplementedError: TODO: in Ruby ->
...`) — that is ruby-gnome's own error string, quoted as evidence of a
binding limitation, not a label the port applied to its own work. Correctly
not rewritten: it is data about the bindings, not an excuse about the port.

## Where the project's own ledgers already do this skill's job

This port's root ledgers were themselves written under versions of this
skill, and it shows: `COMPONENT_PARITY.md`'s GSettings-schema row explicitly
quotes and retracts its own prior excuse ("I had written this row as 'nothing
owed' ... which is the kind of sentence this ledger exists to stop"), and its
flatpak and screenshot rows are already first person and already name the
behaviour rather than the construct ("because I am an idiot who assumed a
`nix build` was a distribution", "because I am an idiot who stopped at taking
the screenshots"). `FINDINGS.md` is explicit that a binding limitation belongs
there, as a reason a gap is *hard*, never in the sentence that describes a gap
as closed. No new instance of the failure this skill targets was found this
round.

## Findings this round adds to the ledger of accountability, not excuses

These are not excuse language — they are **unexamined claims**, which is a
different and real failure: a number presented as current that nobody re-ran.

1. **`TEST_PARITY.md` (root) says "133" examples; this audit re-ran the exact
   command and got 160.** No hit from `find-excuses.sh` — it is not an
   excuse, it is a stale fact presented with the same confidence as a current
   one. A reader who trusted the 133 without re-running it (as a prior round's
   `.reports/test-parity.md` did, repeating "118" and then "133" across two
   rounds without flagging the drift) would believe the suite's scope more
   narrowly than it actually is. The fix is mechanical — re-run and correct
   the number — and is called out in `.reports/test-parity.md`.
2. **No CI wiring exists for either the port's own suite or its driver.**
   `TEST_PARITY.md` (root) states this plainly ("nothing in CI calls it yet"),
   which is the correct, non-excusing way to record it — it names what is
   missing (automated re-verification) rather than asserting the gap away.
   Still worth restating here because it is the root cause of finding 1: a
   number only an audit re-runs by hand is a number that goes stale between
   audits.
3. **This audit itself did not re-run `nix build` / `nix flake check`**,
   because of this session's own time budget, and said so explicitly in
   `.reports/component-parity.md` rather than silently reusing `FINDINGS.md`
   6's closure as if it were re-verified. Recording that limit here too, so
   the next round does not read this audit's silence on Nix as a fresh
   verification.

None of the three above is phrased as a reason anything is finished. All three
name a concrete, checkable thing nobody has re-run, and point at the exact
place a future round should run it.

## Verdict

**No excuse-language violations found.** The port's own ledgers already
practice this skill's discipline, including retracting a past violation in
place rather than deleting it. The one real finding this round contributes is
about staleness of a reported number (test count), not about an excuse for
missing behaviour — and it is reported as a fact to re-check, not softened
into a decision.
