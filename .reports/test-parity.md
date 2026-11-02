# Test parity — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` |
| Port | `ruby` @ `b5f105c` |
| Upstream tests | **3** |
| Ported | **0** |
| Gaps | **3** |
| Port's own examples | 118 (7 spec files) |

## The previous audit of this file was wrong

`.reports/test-parity.md` at `a73a55a` reported **0 upstream tests** and
declared parity "met trivially", citing among other things "no `test` target in
`meson.build`". That claim was checked against the top-level `meson.build`
only. `data/meson.build` declares three:

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
`flatpak/flatpak-github-actions/flatpak-builder@v6`, which runs
`meson test`. These three are what upstream's CI runs on every push, and they
are the upstream suite.

`test-census.sh` cannot see them — it knows GLib `Test.add_func`, unittest,
pytest, Jasmine `it(...)`, Rust `#[test]` and Ruby `test_*`/`it`/`check`, and
not meson `test()`. The skill says to cross-check the census against the build
file's test list. The last audit ran the script and did not do the cross-check,
reported a 0 it had not verified, and spent the rest of the document on how
untested the port is — which was true, and was not the parity finding.

## The census

| # | Upstream test | File:line | Property pinned | Port | Verdict |
|---|---|---|---|---|---|
| 1 | `Validate desktop file` | `data/meson.build:36` | the installed `.desktop` — after `@app-id@` substitution and after `i18n.merge_file` has merged all fifteen translations into it — is a valid desktop entry. Catches a broken `Icon=`, a bad `Categories=`, a malformed translated `Name[xx]` | none | **gap** |
| 2 | `Validate appstream file` | `data/meson.build:58` | the installed `metainfo.xml` — substituted and translation-merged — passes `appstreamcli validate --no-net`. Catches a bad `<id>`, a missing `<launchable>`, a malformed `<release>`, a `<screenshot>` without an `<image>`. An invalid metainfo means the app does not appear in Software | none | **gap** |
| 3 | `Validate schema file` | `data/meson.build:76` | `glib-compile-schemas --strict --dry-run` accepts `data/`. Catches a schema that would make `glib-compile-schemas` fail at install time on a user's machine | none, and nothing to validate — the port ships no schema (`component-parity.md`, gap 7) | **gap** |

Three upstream tests, three gaps, a bijection with nothing on the port side.

The port's install path makes the first two *more* necessary than upstream's,
not less: `flake.nix:180-186` runs the same `msgfmt --desktop` /
`msgfmt --xml` merge that meson does, by hand, into files whose `@app-id@`
was replaced with a literal by hand. Both substitutions and both merges are
unchecked.

### Behaviour owed, per gap

1. a user's launcher shows the app with the right name, icon and translated
   name, in every one of the fifteen languages;
2. GNOME Software shows the app, with its description, release notes and
   screenshots, in every one of the fifteen languages;
3. installing the app does not break the system's compiled schema cache.

Closing all three is cheap and needs no display: three shell invocations over
built files, as a `rake` task and a CI job. `desktop-file-validate`,
`appstreamcli` and `glib-compile-schemas` are all already in the Nix closure
(`flake.nix` uses `glib.dev` at line 208).

## Extra — the port's own suite

Not parity rows; upstream owes them nothing. Recorded because the suite is new
since the last audit and the last audit's headline ("zero spec files") is now
false:

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

**Unverified in this checkout.** `bundle exec rspec` fails here with
`bundler: command not found: rspec` — the gems are not installed outside
`nix develop`, so this audit did not execute a single one of the 118. The last
spec run anyone recorded is `FINDINGS.md` 5's "the other 90 examples run and
pass", which is 28 examples out of date; whatever was added since has never
been shown to pass in any document in this repository.

What the 118 do *not* cover, and what therefore has still never been executed:

| Never executed | Why |
|---|---|
| every widget in `lib/` — 11 units, ~2,900 lines | `require "gtk4"` raises `Gtk::InitError` here (`FINDINGS.md` 5); `spec/wordbook/application_spec.rb` and `shell_search_provider_spec.rb` cannot even load |
| the SQLite reads in `base.rb:96-257` against a real `wn` database | the port ships no database (`component-parity.md`, gap 6), so there is nothing to read |
| `Utils.set_accessible_label`, `compute_bounds`, `set_pointing_to`, `Gtk::Settings#gtk_xft_dpi`, `focus_widget=` | read out of the Gtk-4.0 typelib, never called |

`.claude/skills/ruby-gtk-testing` with `scripts/gtk_driver.rb` is installed and
unused. `CLAUDE.md` says to use it "before claiming any GTK change works".

## Verdict

**Not clean.** 0 of 3 upstream tests ported, and the previous report said
0 of 0.
