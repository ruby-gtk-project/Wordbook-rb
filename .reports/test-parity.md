# Test parity — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` @ `e3c6135` |
| Upstream tests | **3** (`data/meson.build:35-79`, meson `test()`, not a unit-test framework) |
| Ported | **3 / 3** — unchanged, not re-run this pass (no `data/`/`meson.build` diff on upstream since last audit) |
| Port's own spec suite | **re-run this round**: `160 examples, 0 failures`, exit 0 |
| Driver | **re-run this round**: `215 of 215 checks passed`, `DRIVE OK` — not in the 160, and not in CI |

## The suite actually runs — reproduced, not quoted

```
$ nix develop --command xvfb-run -a rspec -O /dev/null -Ilib spec
...
160 examples, 0 failures
```
Exit code 0. The log shows several `[ERROR]` lines mid-run
(`zstd-ruby failed to unpack...`, `JSON::ParserError`, `no database`) — these
are the corrupt-archive/missing-binary/no-database specs deliberately
exercising their failure paths, not suite breakage; each is followed by `.`
(pass) in the dot-progress output, confirmed by reading the full log.

`-O /dev/null` is required in the dev shell because `.rspec` loads
`spec/spec_helper.rb`, which requires `kettle-test`, not present in the
offline bundle.

## The driver actually runs — reproduced, not quoted

```
$ nix develop --command xvfb-run -a ruby test/drive_wordbook.rb
...
215 of 215 checks passed
DRIVE OK
```
This is the second time this exact command has been re-run and reproduced
across rounds (210, then 215 this round) — note it has never once reproduced
at 222, the figure in this round's stated runtime gate. See
`component-identification.md` for that unreconciled number. The driver is not
invoked from `bundle exec rspec`, is not part of the 160 examples, and —
per `TEST_PARITY.md` at the repo root — **nothing in CI calls it**. A driver
that only a human (or an audit agent) remembers to run by hand is not a
regression gate; it is a point-in-time measurement. That remains true this
round.

## What the green numbers still do not cover (unchanged from the root ledger)

- the WordNet reader's real-query behaviour (`entry_rank` ordering, the
  rank-0 lemma subselect, the sense-level antonym join) — exercised only
  against `test/wn_fixture.rb`'s tiny fixture, never a real `wn-*.db`.
- the D-Bus surface — `ShellSearchProvider` is called as plain Ruby by every
  check that touches it; no check has ever gone over a real D-Bus connection
  and had GLib parse the hand-written `GLib::Variant` text back.
- the search-threading generation counters, idle callbacks, and the
  live-search/history timers — these need a running main loop and none of
  the 160 examples or the driver's 215 checks supply one on this path.

## Conclusion

Upstream's census is 3/3 ported. The port's own suite is real, substantial,
and was executed this round with a clean result — this is not a "has it ever
been run" gap. The open items are: (1) the driver, which is the only thing
covering widgets, still runs nowhere but a human's terminal, and (2) three
named code paths (WordNet real-query, D-Bus wire format, search threading)
that no executed check — spec or driver — reaches at all, which is a coverage
gap for those paths specifically, not a "suite never ran" gap.
