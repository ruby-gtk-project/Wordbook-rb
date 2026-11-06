# Test parity — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` |
| Upstream tests | **3** |
| Ported | **3** |
| Gaps | **0** |
| Port command | `nix develop --command rake data:validate`, and `nix flake check` over the built artifact |
| The port's own suite | 9 files, **160 examples, 0 failures** |
| The port's own driver | `test/drive_wordbook.rb`, **210 checks, all passing**, 19 screenshots |

## The census, and why a naive one returns zero

This header said **"Upstream test suite: none — verified: … no test target in
`meson.build` … Parity 0 / 0, met trivially"** for two rounds. That was false,
and I wrote it: I grepped the top-level `meson.build`, found no `test()`, and
reported the whole tree as untested. `data/meson.build` declares three, and
`.github/workflows/CI.yml:26` passes `run-tests: "true"` to
`flatpak/flatpak-github-actions/flatpak-builder@v6`, which runs `meson test` —
so upstream runs all three on every push.

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

A census script that knows GLib `Test.add_func`, unittest, pytest, Jasmine,
Rust `#[test]` and Ruby `test_*`/`it`/`check` does not know meson `test()`, so
it reports 0. Cross-check against the build files; that is what the skill says
and what I did not do. Beyond these three there is no `test/`, no `tests/`, no
pytest or unittest configuration (`setup.cfg`'s only `test` mention is a
pydocstyle `match` pattern) and no test recipe in the `justfile`.

## The ledger

| # | Upstream test | File:line | Purpose — what it pins | Port test | State |
|---|---|---|---|---|---|
| 1 | `Validate desktop file` | `data/meson.build:36` | The **installed** `.desktop` — after `@app-id@` substitution and after all fifteen translations have been merged in — is a valid desktop entry. Catches a broken `Icon=`, a bad `Categories=`, a malformed translated `Name[xx]`. Behaviour: a user's launcher shows the app with the right name and icon, in every one of the fifteen languages | `rake data:validate` (`Rakefile`, `data:validate`) over the generated file, and `checks.data-files` in `flake.nix` over the one `nix build` installs | **ported** |
| 2 | `Validate appstream file` | `data/meson.build:58` | The **installed** `metainfo.xml` — substituted and translation-merged — passes `appstreamcli validate --no-net`. Catches a bad `<id>`, a missing `<launchable>`, a malformed `<release>`, a `<screenshot>` without an `<image>`. Behaviour: GNOME Software shows the app, with its description and screenshots, in every one of the fifteen languages | the same two | **ported** |
| 3 | `Validate schema file` | `data/meson.build:76` | `glib-compile-schemas --strict --dry-run` accepts the schema directory. Catches a schema that would break the system's compiled schema cache at install time. Behaviour: installing the app does not break every other app's settings | the same two, over `data/schemas/dev.mufeed.Wordbook.gschema.xml.in` | **ported** |

Test 3 had nothing to validate until this round, because the port shipped no
GSettings schema at all and I had written that absence up in
`COMPONENT_PARITY.md` as "nothing owed". That excuse closed an upstream test by
deleting the thing it checks. The schema is at
`data/schemas/dev.mufeed.Wordbook.gschema.xml.in` now, `flake.nix` substitutes
and compiles it, and `rake install:data` installs it.

### How the port runs them

```sh
nix develop --command rake data:validate
# builds tmp/validate/dev.mufeed.Wordbook.{desktop,metainfo.xml} and the schema
# from the templates + po/, then runs all three validators. PROFILE=development
# validates the Devel copy's files instead.

nix flake check
# checks.data-files runs the same three over the files `nix build` installed,
# which is the stronger of the two: it validates the artifact, not a rehearsal.
```

`nix flake check` also runs `checks.packaged-database-read`, which is not a
parity row — it exists because the packaged app shipped for a round with
`sqlite3` missing from `nix/gemset.nix`, so every check here was green while the
only installable artifact raised `LoadError` on the user's first search.

## Extra — the port's own suite

Not parity rows; upstream owes them nothing.

```sh
nix develop --command xvfb-run -a rspec -O /dev/null -Ilib spec
```

| File | Covers | Examples |
|---|---|---:|
| `spec/wordbook/base_spec.rb` | `clean_search_terms`, `default_process`, `ratio`, `qratio`, `suggestions`, `normalize_lemma`, `find_best_lemma_match`, `group_synsets_by_lemma`, `pick_pronunciation`, `related_lemmas` | 36 |
| `spec/wordbook/espeak_spec.rb` | `ipa_to_espeak`, `phoneme_input`, the version messages, and the failure paths: no binary on PATH, a non-zero exit, a hang past the timeout, the LRU eviction at `CACHE_LIMIT` | 23 |
| `spec/wordbook/settings_spec.rb` | load, the two pydantic validators, every writer, `batch_update`, `reset_to_defaults`, `PronunciationAccent` | 19 |
| `spec/wordbook/database_builder_spec.rb` | `Wordbook::DatabaseBuilder` — the WordNet-LMF → sqlite loader scripts/generate-wn-db.py drives, synsets, lemmas, relations, the zstd compression step | 16 |
| `spec/wordbook/database_manager_spec.rb` | the paths, the candidate search order, `needs_extraction?`, pruning old versions, extraction through real `zstd`, the corrupt-archive and missing-program failures, `setup` | 15 |
| `spec/wordbook/shell_search_provider_spec.rb` | all five `SearchProvider2` methods, the metas, the detached spawn, the missing-launcher path, the node XML against the `.ini`, and the profile moving the bus name and object path | 16 |
| `spec/wordbook/application_spec.rb` | the option parser (including the two bugs it used to have) and the accelerator table | 13 |
| `spec/wordbook/lmf_reader_spec.rb` | `Wordbook::LmfReader` — streaming parse of the WordNet-LMF XML (synsets, senses, relations, pronunciations) that `DatabaseBuilder` consumes | 12 |
| `spec/wordbook/translations_spec.rb` | every marker in `lib/` against all fifteen catalogues, `po/wordbook.pot`'s key set, `POTFILES`, the domain, the `msgctxt` distinction | 10 |
| | | **160** |

`-O /dev/null` is needed in the dev shell because `.rspec` loads
`spec/spec_helper.rb`, which requires `kettle-test` and the coverage stack —
the project's CI bundle, which is not in `nix/Gemfile` and cannot be installed
offline. On a machine with the development bundle, `bundle exec rspec` is the
command and `spec_helper` loads normally.

And the driver, which is what covers the widgets:

```sh
nix develop --command xvfb-run -a ruby test/drive_wordbook.rb
```

It presents the real application under Xvfb and runs its checks over the window
class, the widget tree, the breakpoint, all eleven actions, every dialog, the
menu, the completion popover, the history sidebar, the definition page, the
empty and error states, the German catalogue on screen and the development
profile's window class. It is a driver, not a spec: it is not in the RSpec run,
and nothing in CI calls it yet.

## What the green numbers still do not cover

- **the WordNet reader.** `Base::Wordnet`'s nine SQL statements run only
  against `test/wn_fixture.rb`'s tiny database, because the port ships no
  WordNet archive (`FINDINGS.md`, defect 7). Nothing checks that `entry_rank`
  ordering, the rank-0 lemma subselect or the sense-level antonym join return
  what `wn` returns.
- **the archive path.** `DatabaseManager#extract_database`, `decompress`,
  `cleanup_old_versions` and `old_version_dirs` are covered by
  `database_manager_spec.rb` but not by any run of the real app, because the
  drive writes the fixture straight into place.
- **the D-Bus surface.** `ShellSearchProvider#run`, `register` and
  `handle_method_call` and the `GLib::Variant` builders are entered by no
  check: the drive calls the five SearchProvider2 methods as plain Ruby, so the
  hand-written GVariant text has never been parsed by GLib.
- **the search threading.** Generation counters, the idle callbacks and the
  live-search and history timers need a main loop and have none of their own.
