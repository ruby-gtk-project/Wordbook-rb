# Test parity — Wordbook-rb

| | |
|---|---|
| Upstream | `main` @ `4b43165` |
| Port | `ruby` @ `a73a55a` |
| Upstream tests | **0** |
| Ported | 0 |
| Gaps | 0 |
| Test command | `bundle exec rspec` (via `rake spec` / `turbo_tests2`) — **0 examples** |

Upstream has no test suite. Verified:

```
$ test-census.sh <upstream> | wc -l
0
```

and by hand: no `test/` or `tests/` directory, no `def test_*`, no `unittest`,
no `pytest`, no `conftest.py`, no `[tool.pytest]` or `testpaths` in
`pyproject.toml` or `setup.cfg`, no `test` target in `meson.build`,
`meson_options.txt` or the `justfile` (which has `setup`,
`local-configure`, `develop-configure`, `local-run`, `install`, `clean`, `run`
and nothing else), and no test job in `.github/workflows/CI.yml` beyond lint.
`setup.cfg`'s `[pydocstyle] match = '(?!test_).*\.py'` names a convention
nobody used.

Parity is **0/0 and is met trivially.**

**The port therefore inherits no safety net.** There is no upstream test that
pins the search-term cleanup charsets, the IPA→espeak phoneme table, the
50-entry history cap, the 20-entry load truncation, the lemma grouping, the
pronunciation-variety fallback, the zstd extraction's atomic rename, or any of
the D-Bus search-provider methods — because upstream never wrote one. Every
behaviour in this port was reimplemented from reading, and nothing anywhere
checks that the reading was right.

## Extra

None. This is the finding.

The port carries a complete RSpec harness and does not use it:

| File | State |
|---|---|
| `spec/spec_helper.rb` | present (39 lines, `kettle-test` bootstrap) |
| `spec/README.md` | present |
| `spec/**/*_spec.rb` | **zero files** |
| `.rspec`, `.rubocop_rspec.yml`, `.simplecov`, `gemfiles/modular/rspec.gemfile`, `gemfiles/modular/coverage.gemfile`, `bin/turbo_tests2` | all present and configured |

So `bundle exec rspec` reports 0 examples, 0 failures, and the CI that runs it
is green. 4,421 lines of `lib/` and `exe/` — including a 970-line window, a
530-line WordNet layer with a hand-written SQLite schema reader, a hand-written
Levenshtein/LCS ratio standing in for `rapidfuzz`, and a hand-written option
parser standing in for `GLib.OptionEntry` — have never been executed by
anything in this repository.

`CLAUDE.md` says: *"ruby-gtk-testing — run the app headlessly and drive its UI
… Use it before claiming any GTK change works. `ruby -c` and a successful
`require` prove nothing about a UI."* The skill is installed at
`.claude/skills/ruby-gtk-testing/` with a driver at `scripts/gtk_driver.rb`.
Nothing in the port uses it, and in this checkout the port cannot even be
loaded: `require "gtk4"` raises `LoadError` outside `nix develop`.

Parity is met. The port is untested. Both sentences are true and the second one
is the one that matters, so it is written here rather than left as an
implication.

## Behaviour owed by a suite that does not exist

Not parity rows — upstream owes these nothing. Listed because `## Extra` would
otherwise be an empty section on a port where the absence of tests is the
largest single risk, and because these are the places where the port
reimplemented an algorithm rather than a call:

| Behaviour | Where the port reimplements it |
|---|---|
| the `rapidfuzz` QRatio score, as an LCS ratio | `lib/wordbook/base.rb:471-530` |
| the pydantic validators (accent fallback, history truncation) | `lib/wordbook/settings.rb:226` |
| the `wn` package's SQLite schema reads | `lib/wordbook/base.rb:165-245` |
| the `bisect`-over-casefold completion ranking | `lib/wordbook/window.rb:549-581` |
| the four `GLib.OptionEntry`s, hand-parsed | `lib/wordbook/application.rb:160-180` |
| the zstd extraction and old-version pruning | `lib/wordbook/database_manager.rb` |
| the IPA→espeak phoneme substitution table | `lib/wordbook/espeak.rb:92` |
