# Test parity — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` @ `9b3afaf` |
| Upstream tests | **3** (`data/meson.build:35-79`, via meson `test()`, not a unit-test framework) |
| Ported | **3 / 3**, reproduced this round |
| Gaps | **0** on the upstream census; see below for a second kind of gap this round found |

## The three upstream tests, reproduced

```
$ nix develop --command rake data:validate
msgfmt --desktop ... / msgfmt --xml ...
desktop-file-validate tmp/validate/dev.mufeed.Wordbook.desktop
  → hint only (extendable Categories), not a failure
appstreamcli validate --no-net tmp/validate/dev.mufeed.Wordbook.metainfo.xml
  → ✔ Validation was successful: infos: 1, pedantic: 1
glib-compile-schemas --strict --dry-run tmp/validate/schemas
  → (silent success)
```

All three of upstream's `test()` calls (`Validate desktop file`,
`Validate appstream file`, `Validate schema file`) have a named Ruby
counterpart (`rake data:validate`, run against the port's own generated files)
and passed when run in this audit, not merely cited as passing. This matches
`TEST_PARITY.md`'s ledger at the root, and that ledger's census method — the
naive test-counting script returns 0 because meson's `test()` is not a
framework it knows, and the honest fix is to read `data/meson.build` by hand,
which both the root ledger and this audit did.

## The port's own suite — reproduced, and the root ledger is stale

```
$ nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; RSpec::Core::Runner.run(["-O","/dev/null","-Ilib","spec"])'
160 examples, 0 failures
```

**`TEST_PARITY.md` (root) and `.reports/test-parity.md`'s prior version both
say 133.** The suite now has 160 examples with the same command, same flags,
same checkout. This is not a parity gap against upstream (upstream has no unit
tests for this suite to track one-for-one; these are the port's own, and
upstream owes none of them) — but it is exactly the kind of staleness the
`accountability-ensurance` skill exists to catch: a number in an authoritative
ledger that nobody re-ran before trusting. See
`.reports/accountability-ensurance.md`.

(One stack trace prints to stderr mid-run, from
`spec/wordbook/shell_search_provider_spec.rb`'s "survives a lookup that
raises" example, which exercises `Utils.log_error`'s logged backtrace on
purpose — not a failure; the run ends `0 failures`.)

## The port's own driver — reproduced

```
$ nix develop --command xvfb-run -a ruby test/drive_wordbook.rb
210 of 210 checks passed
DRIVE OK
```

Matches the runtime gate given for this audit (`drive_ok=true`, 210 checks, 0
failed). Reproduced from this checkout, not quoted from the gate's own report.

## What the green numbers still do not cover (unchanged from the root ledger, re-checked)

- **The WordNet reader's correctness against real `wn`-format data.**
  `Base::Wordnet`'s SQL only ever runs against `test/wn_fixture.rb`'s small
  hand-built database (in the drive) or `spec`'s small generated one (in
  `database_builder_spec.rb`). Nothing in the repository runs it against the
  real 161,875-entry Open English WordNet archive and diffs a result against
  Python's `wn` package's answer for the same lookup. `FINDINGS.md` 7 records
  the archive-generation side of this as closed; it does not claim the
  *lookup* result has ever been cross-checked against upstream's own output,
  and nothing here does either.
- **The archive extraction path** (`extract_database`, `decompress`,
  `cleanup_old_versions`) is covered by `spec/wordbook/database_manager_spec.rb`
  but still not by the drive, which writes the fixture straight into place —
  unchanged from the prior audit.
- **The D-Bus surface** — see `.reports/component-parity.md` gap C. Covered by
  `spec/wordbook/shell_search_provider_spec.rb` calling the provider's methods
  directly, never by an actual D-Bus round trip.
- **A suite that has executed is not the same claim as a suite that executes
  in CI.** `.github/workflows/CI.yml` on `origin/main` runs upstream's three
  `meson test`s on every push via the flatpak-builder action. This port's
  `test/drive_wordbook.rb` and its `rspec` suite are run by hand in a dev
  shell in audits like this one; nothing in this repository runs either on
  push. That both ran green in this audit is reproduced fact; that they will
  keep running green on the next change is not, because nothing automated
  checks it.

## Verdict

**Not a census gap** — 3/3 upstream tests map to a named, reproduced Ruby
counterpart, and the port's own suite (160 examples) and driver (210 checks)
both run and pass, reproduced in this session rather than quoted. **Is a
staleness gap**: the root `TEST_PARITY.md` undercounts its own suite by 27
examples, which means the last round that touched it did not re-run the
number it published. And is a process gap: none of this is wired into CI, so
"the suite runs" is true only when a human or an audit runs it.
