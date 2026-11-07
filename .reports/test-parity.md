# Test parity — Wordbook-rb

Audit round — the suite and the drivers were executed live for this report.

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` |
| Port | `ruby` @ `d3c3f60` |
| Upstream tests | **3** — `data/meson.build:35-79`'s three `test()` calls (`desktop-file-validate`, `appstreamcli validate --no-net`, `glib-compile-schemas --strict --dry-run`); not a unit-test framework |
| Ported | **3 / 3** via `rake data:validate` (re-read against `data/meson.build:35-79` this round, mapping unchanged) |
| Port's own suite | **re-run this round** |
| Main driver | **re-run this round** |
| D-Bus search-provider driver | **re-run this round, three times — this is the round's main finding** |

## Reproduced live, this round

```
$ nix develop --command xvfb-run -a rspec -O /dev/null -Ilib spec
...
160 examples, 0 failures
```
Exit 0.

```
$ nix develop --command xvfb-run -a ruby test/drive_wordbook.rb
...
215 of 215 checks passed
DRIVE OK
```
Matches the runtime gate given for this audit exactly (215 passed, 0 failed).

## The finding this round: a driver that is "green" only most of the time

`test/drive_search_provider_dbus.rb` drives the search provider over a real
D-Bus session bus. `PORTING.md`'s "Open gaps" section currently lists "The
search provider's D-Bus surface has never been run" as **closed**, citing
this file. This round ran it three consecutive times, unmodified, same
checkout, same environment:

```
run 1: 7 of 7 checks passed — DBUS DRIVE OK
run 2: 7 of 7 checks passed — DBUS DRIVE OK
run 3: 1 of 7 checks passed — DBUS DRIVE FAILED (6)
```

This is not an environment fluke outside the port's control: isolated with a
debug copy of the same script, the failing run's `GetInitialResultSet` call
landed before the provider's object registration had completed, even though
the bus name was already owned (`NameHasOwner` and object `register()` are
two separate calls, and nothing synchronizes the second against the
driver's "name is owned" check). Every downstream check in a failing run
cascades from that first miss, because each later `gdbus_call` depends on a
result id produced by the step before it.

**This matters for "is every upstream behaviour verified", the subject of
this report**: a test that passes 2 times out of 3 has not actually verified
anything about the one time it was cited as proof. The underlying
`SearchProvider2` implementation itself is not shown broken — every run that
clears the race passes all 7 checks, including both action methods — but the
claim that this axis is "closed" is not supported by a driver this flaky.
See `component-parity.md` and `accountability-ensurance.md`.

## The suite actually runs — not a stale claim

The rspec suite, the main driver, and the D-Bus driver were all invoked live
in this session, from a clean shell, under the dev shell's documented
commands. The rspec and main-driver figures reproduced exactly; the D-Bus
driver did not reproduce consistently, and that inconsistency is itself
reported rather than smoothed over by citing only the two passing runs.

## Gaps

- **0** — all three upstream `data/meson.build` tests are ported, and the
  port's own rspec suite and main driver both execute to green on a fresh
  run, reproduced exactly.
- **1 reliability gap** — the D-Bus search-provider driver is flaky (racy
  object-registration ordering), so its "closed" status in `PORTING.md` is
  not fully earned. Not a missing test; an unreliable one, incorrectly
  reported as settled.

## Also re-run live this round

```
$ nix flake check
...
all checks passed!
```
`checks.packaged-database-read` (the packaged-app-can-read-a-database check
added after the `sqlite3`-missing-from-gemset defect) and `checks.data-files`
both built and passed from a clean evaluation. The packaged-app axis is not
an untested carry-forward this round either.

## Not independently re-verified this round

- The archive-extraction path (`rake wn:db` against the real OEWN release,
  `DatabaseBuilder` writing and `DatabaseManager` extracting a real
  multi-megabyte `.zst`) was not re-run live this session; the previous
  round's report (`PORTING.md`'s gap-1 entry) documents having run it for
  real with specific figures (73.9 MB / 161,875 entries). This round trusts
  that account rather than re-downloading the lexicon.
