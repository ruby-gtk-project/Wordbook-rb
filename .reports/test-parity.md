# Test parity — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` |
| Port | `ruby` @ `0a35cd6` |
| Upstream tests | **3** |
| Ported | **0** |
| Gaps | **3** |
| Test command | `nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; …'` (the dev shell's banner names it) |
| Port's own examples | **118, executed in this audit, 0 failures** |
| Port's own drive checks | **198, executed in this audit, `DRIVE OK`** |

## The census, and why the script returns zero

```
$ .claude/skills/test-parity/scripts/test-census.sh <upstream> | wc -l
0
```

That zero is wrong and the skill says why: cross-check the census against the
build file's test list. `data/meson.build` declares three `test()` calls, and
`test-census.sh` knows GLib `Test.add_func`, unittest, pytest, Jasmine,
Rust `#[test]` and Ruby `test_*`/`it`/`check` — not meson `test()`.

```meson
# data/meson.build:35-38
desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
  test('Validate desktop file', desktop_utils, args: [desktop_file.full_path()])
endif

# data/meson.build:57-61
appstreamcli = find_program('appstreamcli', required: false)
if appstreamcli.found()
  test('Validate appstream file', appstreamcli, args: ['validate', '--no-net', appstream_file.full_path()])
endif

# data/meson.build:75-79
compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('Validate schema file', compile_schemas, args: ['--strict', '--dry-run', meson.current_source_dir()])
endif
```

`.github/workflows/CI.yml:26` passes `run-tests: "true"` to
`flatpak/flatpak-github-actions/flatpak-builder@v6`, which runs `meson test`.
These three are what upstream's CI runs on every push, and they are the
upstream suite. There is no `test/`, no `tests/`, no pytest or unittest
configuration (`setup.cfg`'s only `test` mention is a pydocstyle `match`
pattern), and no test recipe in the `justfile`.

## The ledger

| # | Upstream test | File:line | Property pinned | Port test | State |
|---|---|---|---|---|---|
| 1 | `Validate desktop file` | `data/meson.build:36` | the *installed* `.desktop` — after `@app-id@` substitution and after all fifteen translations have been merged in — is a valid desktop entry. Catches a broken `Icon=`, a bad `Categories=`, a malformed translated `Name[xx]` | — | **gap** |
| 2 | `Validate appstream file` | `data/meson.build:58` | the *installed* `metainfo.xml` — substituted and translation-merged — passes `appstreamcli validate --no-net`. Catches a bad `<id>`, a missing `<launchable>`, a malformed `<release>`, a `<screenshot>` without an `<image>`. An invalid metainfo means the app never appears in Software | — | **gap** |
| 3 | `Validate schema file` | `data/meson.build:76` | `glib-compile-schemas --strict --dry-run` accepts `data/`. Catches a schema that would break the system's compiled schema cache at install time | — and nothing to validate: the port ships no schema (`component-parity.md`, gap 4) | **gap** |

Three upstream tests, three gaps, a bijection with nothing on the port side.
No `rake` task, no CI job and no script in this repository runs any of the
three — grepped:

```
$ grep -rn 'desktop-file-validate\|appstreamcli\|glib-compile-schemas' .gitlab-ci.yml .github Rakefile
(nothing)
```

### Behaviour owed, per gap

1. a user's launcher shows the app with the right name and icon, and with the
   translated name, in every one of the fifteen languages;
2. GNOME Software shows the app, with its description, release notes and
   screenshots, in every one of the fifteen languages;
3. installing the app does not break the system's compiled schema cache.

### I ran two of the three by hand, and they pass today

Because a gap that is cheap to close should be reported as cheap, and because
a reader deserves to know whether the port's data is *broken* or merely
*unchecked*. Against the artifact `nix build` produces:

```
$ desktop-file-validate …/share/applications/dev.mufeed.Wordbook.desktop
hint: value item "Dictionary" in key "Categories" … can be extended with
      another category among: Office, or TextTools          # exit 0

$ appstreamcli validate --no-net …/share/metainfo/dev.mufeed.Wordbook.metainfo.xml
I: dev.mufeed.Wordbook:196: nonstandard-gnome-extension kudos
✔ Validation was successful: infos: 1, pedantic: 1          # exit 0
```

So the data is good **right now** and nothing guarantees it stays good. The
port's install path makes these two checks *more* necessary than upstream's,
not less: `flake.nix:179-185` runs the same `msgfmt --desktop` /
`msgfmt --xml` merges that meson's `i18n.merge_file` does, by hand, into files
whose `@app-id@` was replaced with a literal by hand. Both substitutions and
both merges are unchecked. Closing all three needs no display — three shell
invocations over built files, as a rake task plus a CI job, and
`desktop-file-utils`, `appstream` and `glib.dev` are already reachable from the
flake.

The third cannot be run at all: there is no schema to validate. It closes when
`component-parity.md` gap 4 closes.

## The previous ledger at the repository root is still a false clean

`TEST_PARITY.md` on `ruby` @ `0a35cd6` says:

> | Upstream test suite | **none** — verified: no `test/`, no `tests/`, no pytest
> or unittest configuration, **no test target in `meson.build`**, no test recipe
> in the `justfile` |
> | Parity | 0 / 0, met trivially |

That is the exact claim the previous round of this report refuted, with the
exact piece of wrong evidence that was refuted — "no test target in
`meson.build`" was checked against the top-level `meson.build` only, and
`data/meson.build` declares three. The correction was written into `.reports/`
and never carried into the ledger the skill calls the contract. A reader of
`TEST_PARITY.md` is told parity is met. See
`accountability-ensurance.md`, hit 2; it is the most serious finding in this
round.

## Extra — the port's own suite

Not parity rows; upstream owes them nothing. **Executed in this audit**, which
is the thing the last two rounds could not say:

```
$ nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run([…])'
118 examples, 0 failures
```

| File | Examples |
|---|---:|
| `spec/wordbook/base_spec.rb` | 36 |
| `spec/wordbook/settings_spec.rb` | 19 |
| `spec/wordbook/database_manager_spec.rb` | 16 |
| `spec/wordbook/shell_search_provider_spec.rb` | 15 |
| `spec/wordbook/application_spec.rb` | 13 |
| `spec/wordbook/espeak_spec.rb` | 11 |
| `spec/wordbook/translations_spec.rb` | 8 |
| | **118** |

No pending, no skipped, no example that fails to load. The two files the last
round reported as unloadable (`application_spec.rb`,
`shell_search_provider_spec.rb`) load and pass — `FINDINGS.md` 5 is closed and
the dev shell's Xvfb is why.

And the driver:

```
$ nix develop --command xvfb-run -a ruby test/drive_wordbook.rb
198 of 198 checks passed
DRIVE OK
```

78 steps, 19 screenshots into `tmp/shots`. I re-ran it rather than quoting it.

## What the green numbers still do not cover

Line coverage over `lib/` **under the drive run**, measured with Ruby's
`Coverage` (`lines: true`), is **1833 / 2038 = 89.9 %** across 26 files, and
**every one of the 26 is entered** — so the "26 components" in the gate are
genuinely exercised, not nominally listed. The uncovered fifth is not spread
thin; it is three whole behaviours:

| Never executed by any check | Lines | Why it matters |
|---|---:|---|
| `database_manager.rb`'s archive path — `extract_database`, `decompress`, the `zstd` call and its two failure raises, `cleanup_old_versions`, `old_version_dirs`, the success branch of `find_compressed_db` | 31 of 68 | this is every line a real install runs. The drive searches `test/wn_fixture.rb`'s database, written straight into place, so the archive is never unpacked (`component-parity.md`, gap 3) |
| `shell_search_provider.rb`'s D-Bus surface — `run`, `register`, `handle_method_call`, the `Process.spawn`, and the `GLib::Variant` builders `string_array` / `metas_variant` / `quote` | 33 of 90 | GNOME Shell is the only caller of this file and it is the only caller no check makes. The six green checks in the provider step call plain Ruby methods (`component-parity.md`, gap 8) |
| `espeak.rb`'s failure paths — the `TERM` timeout kill, the non-zero exit, `Errno::ENOENT`, the LRU eviction, the whole `--version` path behind `--info` | 23 of 70 | upstream degrades silently when espeak-ng is absent; nothing shows this port does (`component-parity.md`, gap 9) |

Also still unexecuted anywhere: the SQLite reads in `base.rb` against a real
`wn` lexicon — the port ships no database, so the fixture's schema is what has
been read, not upstream's data; and the packaged artifact, which raises
`LoadError: cannot load such file -- sqlite3` on the first search
(`component-parity.md`, gap 7). What the 198 checks and the 118 examples prove
is the source tree under the dev shell. They prove nothing about either thing a
user installs.

## Verdict

**Not clean.** 0 of 3 upstream tests ported, and the root ledger still says
0 of 0, met trivially. The port's own suite is real, executed and green — 118
examples and 198 drive checks, both re-run here — and it is extra, every bit of
it, because not one of the three things upstream thought worth checking is
checked by any of it.
