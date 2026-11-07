# Test parity — Wordbook-rb

Audit round — the suite and the driver were both executed live for this
report, not quoted from a prior run.

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` |
| Port | `ruby` @ `665cb58` |
| Upstream tests | **3** — `data/meson.build:35-79`'s three `test()` calls (`desktop-file-validate`, `appstreamcli validate --no-net`, `glib-compile-schemas --strict --dry-run`); not a unit-test framework |
| Ported | **3 / 3** via `rake data:validate` (unchanged this round; `git diff <last-audited-sha> -- data/meson.build` on `origin/main` is empty, so this is a carry-forward of a prior census, not re-derived from a fresh read — but the mapping itself was re-read against `data/meson.build:35-79` this round and still names exactly these three) |
| Port's own suite | **re-run this round** |
| Driver | **re-run this round** |

## Reproduced live, this round

```
$ nix develop --command xvfb-run -a rspec -O /dev/null -Ilib spec
...
160 examples, 0 failures
```
Exit 0. Several `[ERROR]`/exception-trace lines appear mid-run
(`zstd-ruby failed to unpack...`, `JSON::ParserError`, "No compressed database
found") — these are the suite's own negative-path specs (corrupt-archive,
malformed-settings-JSON, missing-database) logging through the app's real
error path and then asserting on it, not uncaught failures; the run still
ends `0 failures`, exit code 0.

```
$ nix develop --command xvfb-run -a ruby test/drive_wordbook.rb
...
215 of 215 checks passed
DRIVE OK
```
This matches the runtime gate given for this audit (215 passed, 0 failed) and
is the **same figure this round's live run reproduced**, not an assumed
match. Note the root `TEST_PARITY.md` still says "210 checks" for this
driver — stale by 5 against both this round's run and `.reports/`'s last
figure; see accountability-ensurance.

## The suite actually runs — not a claim

The suite "has never been executed" caution this skill asks for does not
apply here: both the rspec suite and the driver were invoked in this session,
from a clean shell, under the dev shell's own documented commands, and both
produced the counts above. This is the one axis of the whole audit where
"ran once, long ago, cited forever" would be the worst possible finding, and
it is not what happened — it was ran again, now, for this report.

## Gaps

**0.** All three upstream tests are ported and the port's own suite and driver
both execute to green on a fresh run. No upstream test target was found in
`origin/main` outside `data/meson.build`'s three (`git grep -n 'test(' origin/main -- '*.build'`
shows nothing further).

## Not independently re-verified this round

- The D-Bus search-provider driver (`test/drive_search_provider_dbus.rb`,
  "7 checks" per a prior report) was **not re-run this session** — running it
  requires a private D-Bus session bus and `gdbus`, and this round's time
  went to the rspec suite and the main driver instead. This is a carry-forward,
  not a reproduction, and is named as such rather than folded into the "215"
  figure above (which is the main driver only).
