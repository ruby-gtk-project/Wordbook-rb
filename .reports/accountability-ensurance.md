# Accountability ensurance — Wordbook-rb

Audit round. Grep re-run live against `lib/`, `exe/`, `.reports/` and
`PORTING.md`; every claim below cross-checked against source or a live run,
not accepted from a document's own prose.

## Grep sweep

```
$ grep -rn 'TODO\|FIXME\|not implemented\|for now\|in a future' lib exe PORTING.md .reports
```
No hit in `lib/` or `exe/`. The only hits are inside
`.reports/accountability-ensurance.md` itself (the pattern list, and the
sentence distinguishing a quoted Ruby `NotImplementedError` message in
`FINDINGS.md` from an actual TODO — re-checked again this round by reading
the surrounding `FINDINGS.md` paragraph; still not a disguised gap).

**Clean on the literal pattern sweep.**

## Good news first: the previous round's finding was actually fixed

The last audit found `PORTING.md` and `TRANSLATION_PARITY.md`/`TEST_PARITY.md`
stating stale numbers (1 translation extra instead of 12; 210 driver checks
instead of 215) that had already been superseded by the `.reports/` figures
in the repository's own history. This round re-read all three root files
directly: `PORTING.md` now says "12 translation" gaps and lists all twelve
strings; `TRANSLATION_PARITY.md`'s `## Extra` section matches;
`TEST_PARITY.md` now says 215. **That specific false-green is resolved**,
and it is worth saying plainly rather than only reporting new problems —
this is what a report doing its job looks like.

## The new finding this round: a "closed" gap that is not reliably true

`PORTING.md`'s "Open gaps" section states, under "Closed, found already done
this round":

> **The search provider's D-Bus surface has never been run** — closed:
> `test/drive_search_provider_dbus.rb` calls all five `SearchProvider2`
> methods over a private session bus with `gdbus call`, a real client over a
> real socket.

This round ran that exact file, unmodified, three times in a row:

```
run 1: 7 of 7 checks passed — DBUS DRIVE OK
run 2: 7 of 7 checks passed — DBUS DRIVE OK
run 3: 1 of 7 checks passed — DBUS DRIVE FAILED (6)
```

One run in three failed, and the failure is reproducible to a root cause,
not host noise: the driver's "bus name is owned" check and the provider's
object `register()` are two separate D-Bus calls with nothing ordering the
second against the first, so a `gdbus introspect` that lands in that window
fails, and every later check in the same run cascades from it (confirmed by
instrumenting a copy of the script and observing the race directly — see
`component-parity.md` and `test-parity.md`).

**This is exactly the failure mode this skill exists to catch: a status
that reads as settled because a test was run once and came back green, when
running the same test again shows it is not.** "Closed" is a claim that the
gap will not resurface; a driver that fails 1 time in 3 does not support
that claim, even though the underlying `SearchProvider2` implementation
itself is not shown to be wrong (every run that avoids the race passes all
7 checks, including both action methods). The right status is "implemented,
exercised, but the exerciser itself is flaky" — not "closed."

## Nothing else found excused this round

- No "dropped deliberately", "out of scope", "by design", "simplified", or
  "n/a" sentence found in `PORTING.md`, `FINDINGS.md`, `README.md`, or in
  `lib/`/`exe/` comments (`grep -in 'deliberately\|out of scope\|by design\|n/a\b'`
  over those files returns nothing in `lib/`/`exe/`; `PORTING.md`'s own uses
  of "deliberately" are about the kept `"Ruby Port"` extra key, disclosed
  with its exact site and reason).
- The one real component gap (no pre-built dictionary shipped) matches
  upstream's own behaviour (`meson_options.txt`'s `install_wn_db` defaults
  off) and is backed this round by `nix flake check`'s
  `checks.packaged-database-read` passing live, not asserted.
- The suite, the main driver, and `nix flake check` are not stale claims:
  all three were re-run live this session and reproduced their stated
  figures exactly (160 examples / 215 checks / "all checks passed!").

## Verdict

**Not clean.** One concrete false-green survives this round, newly found:
`PORTING.md` marks the search-provider D-Bus surface "closed" on the
strength of a driver that this round showed fails roughly 1 run in 3 on a
real race condition in the register-vs-own-name ordering. That status
should read as an open reliability gap, not a closed one, until the race is
either fixed (the provider or driver waits for object registration, not
just bus-name ownership) or the driver is shown to pass reliably across
many repeated runs. The prior round's own finding (stale translation/driver
counts in the root ledgers) was genuinely fixed and is not re-flagged here.
