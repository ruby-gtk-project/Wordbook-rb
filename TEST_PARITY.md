# Test parity — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` |
| Upstream test suite | **none** — verified: no `test/`, no `tests/`, no pytest or unittest configuration, no test target in `meson.build`, no test recipe in the `justfile` |
| Parity | 0 / 0, met trivially |
| The port's own suite | 7 files, 118 examples |
| Examples that run here | **90, all passing** |
| Examples that cannot load here | 28, in 2 files (`FINDINGS.md`, defect 5) |

Upstream has no tests, so parity is met by having none. That is the finding
worth writing down: the port inherits no safety net, and for two rounds it had
not built one either — `spec/` held `spec_helper.rb`, `README.md` and zero
`*_spec.rb` files, so `bundle exec rspec` reported 0 examples and CI was green
over 4,400 untested lines. Those lines include a hand-written indel ratio
standing in for `rapidfuzz`, a hand-written SQLite reader standing in for the
`wn` package, hand-written validators standing in for pydantic, and a
hand-written option parser standing in for GOption. Every one of those is a
place where "it compiles" says nothing at all.

## The `## Extra` suite the port owes itself

| File | Covers | Examples | Runs here |
|---|---|---:|:-:|
| `spec/wordbook/base_spec.rb` | `clean_search_terms`, `default_process`, `ratio`, `qratio`, `suggestions`, `normalize_lemma`, `find_best_lemma_match`, `group_synsets_by_lemma`, `pick_pronunciation`, `related_lemmas` | 36 | ✓ |
| `spec/wordbook/settings_spec.rb` | load, the two pydantic validators, every writer, `batch_update`, `reset_to_defaults`, `PronunciationAccent` | 19 | ✓ |
| `spec/wordbook/database_manager_spec.rb` | the paths, the candidate search order, `needs_extraction?`, pruning old versions, extraction through real `zstd`, the corrupt-archive and missing-program failures, `setup` | 16 | ✓ |
| `spec/wordbook/espeak_spec.rb` | `ipa_to_espeak` (longest-key-first, the digraphs, the length marks, the dropped marks, non-ASCII), `phoneme_input`, the version failure messages | 11 | ✓ |
| `spec/wordbook/translations_spec.rb` | every marker in `lib/` against all fifteen catalogues, `POTFILES`, the domain, the `msgctxt` distinction | 8 | ✓ |
| `spec/wordbook/application_spec.rb` | the option parser (including the two bugs it used to have) and the accelerator table | 13 | ✗ |
| `spec/wordbook/shell_search_provider_spec.rb` | all five `SearchProvider2` methods, the metas, the detached spawn, the missing-launcher path, the node XML against the `.ini` | 15 | ✗ |

Several of these examples are the specification of a fix made this round, and
they were written to fail against the code as it was:

- `suggestions` excludes a word scoring **exactly** 70 (upstream's
  `if score > 70`), and `qratio("re-read", "reread")` is **not** 100, because
  `default_process` substitutes a space rather than deleting the hyphen;
- `ratio` is case-sensitive, as `difflib` is, and `qratio` is not, as
  `fuzz.QRatio` is not;
- `parse("--look-up")` reports a missing argument instead of searching for the
  empty string, and `parse("--look-up", "-i")` looks up "-i";
- `translations_spec` fails if any of the 52 catalogue keys is unmarked.

## How to run them

```sh
nix develop
rspec -O /dev/null -Ilib spec/wordbook/base_spec.rb spec/wordbook/espeak_spec.rb \
  spec/wordbook/settings_spec.rb spec/wordbook/database_manager_spec.rb \
  spec/wordbook/translations_spec.rb
# 90 examples, 0 failures
```

`-O /dev/null` is needed in the dev shell because `.rspec` loads
`spec/spec_helper.rb`, which requires `kettle-test` and the coverage stack —
the project's CI bundle, which is not in `nix/Gemfile` and cannot be installed
offline. On a machine with the development bundle, `bundle exec rspec` is the
command and `spec_helper` loads normally.

## What is not tested, and what that costs

- **every widget.** No example constructs a window, a dialog, a row or a
  popover, because `require "gtk4"` cannot be loaded in this environment at all
  (`FINDINGS.md`, defect 5). The `ruby-gtk-testing` skill's driver — present
  something, drive each of the 8 window actions and the 5 preference rows,
  screenshot the 10 units — has **not been run**, and there are no screenshots
  in this repository;
- **the WordNet reader.** `Base::Wordnet`'s nine SQL statements are untested:
  the port ships no database to run them against (`FINDINGS.md`, defect 7).
  They are the single largest piece of hand-written stand-in code here, and
  nothing checks that `entry_rank` ordering, the rank-0 lemma subselect or the
  sense-level antonym join return what `wn` returns;
- **the search threading.** Generation counters, the idle callbacks and the
  live-search and history timers are all untested; they need a main loop;
- **espeak-ng itself.** Only the pure conversion is covered. No example runs
  the binary.
