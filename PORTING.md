# Porting Wordbook to Ruby

Resume point for the next run. Factual; every claim below is either read out of
`origin/main`, read out of `lib/`, or quoted from a report in `.reports/`.

**This port runs, and has been watched running.** The dev shell carries Xvfb,
so `nix develop --command xvfb-run -a ruby test/drive_wordbook.rb` presents the
real application and walks it; `nix build` produces an installable artifact
that opens, prints `--info` and reads a database. The header of this file said
"Nothing in this port has ever been rendered" and `Units verified on screen
0 / 11` for a round after that stopped being true, which is the single most
expensive kind of staleness: it sends the next round to re-do work that is
done, and it cites a `FINDINGS.md` defect as the reason, which keeps the defect
alive after it has been closed.

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` (Python/PyGObject + Blueprint + meson) |
| Port | `ruby` branch (Ruby 3.4, `gtk4`/`adwaita` gems, gem layout) |
| Upstream as spec | read with `git show origin/main:<path>`; never checked out, never merged |
| Units mapped | 11 / 11 |
| Units exercised on screen | **11 / 11** |
| `lib/` line coverage under the drive | 89.9 % (1833 / 2038), all 26 files entered |
| The port's own suite | **133 examples, 0 failures**, executed |
| The driver | **`test/drive_wordbook.rb`**, **210 checks, 0 failures**, 19 screenshots into `tmp/shots` |
| Upstream tests ported | **3 / 3** (`rake data:validate` and `nix flake check`) |
| Open gaps | **8 component, 0 test, 1 translation** |

## Upstream

Wordbook is a GTK4/Libadwaita offline English dictionary that looks terms up in
a bundled WordNet database, showing definitions, examples, synonym/antonym
relations, IPA pronunciations with espeak-ng read-aloud, a favouritable search
history sidebar and a GNOME Shell search provider. It is implemented in Python
(PyGObject) with Blueprint (`.blp`) UI definitions, built with meson. The spec
lives on the `origin/main` ref of this repository.

Three `.blp` files hold the declarative UI (`window.blp` carrying both the
`$WordbookWindow` template and the `menu app-menu` block, `settings-window.blp`,
`shortcuts-dialog.blp`); seven Python modules hold the logic; `po/` holds 15
catalogues; `data/meson.build` declares the three tests upstream's CI runs.

## Done

Implemented and complete on all four axes (widget set, properties, signals,
strings), per `.reports/component-parity.md`, and every one of them is on
screen under the driver.

| Port | Upstream |
|---|---|
| `lib/wordbook/main_menu.rb` | `data/resources/ui/window.blp:4-42` (`menu app-menu`) |
| `lib/wordbook/definition_view.rb`, `definition_row.rb`, `relation_box.rb`, `pronunciation_row.rb` | `ui/window.blp:224-236` + `_populate_definitions` / `_create_*` in `wordbook/window.py` |
| `lib/wordbook/settings_dialog.rb` | `ui/settings-window.blp` + `wordbook/settings_window.py` |
| `lib/wordbook/about_dialog.rb` | `on_about` in `wordbook/main.py` |
| `lib/wordbook/error_dialog.rb` | `_new_error` in `wordbook/window.py` |
| `lib/wordbook/search_completion.rb` | `wordbook/search_completion.py` |
| `lib/wordbook/shell_search_provider.rb`, `exe/wordbook-search-provider`, `data/dev.mufeed.Wordbook.SearchProvider.ini`, `.service.in` | `data/search_provider.in` + `data/dev.mufeed.Wordbook.SearchProvider.ini` |

| `lib/wordbook/window.rb` | `ui/window.blp` (template) + `wordbook/window.py` — an `Adwaita::ApplicationWindow` with the `Adw.Breakpoint` installed on it, both observed |
| `lib/wordbook/history_sidebar.rb`, `history_row.rb`, `history_object.rb` | `ui/window.blp:61-145` + history half of `window.py` — the filter button carries `action-name: "win.toggle-favorites"` and is driven from both ends |
| `lib/wordbook/shortcuts_dialog.rb` | `ui/shortcuts-dialog.blp` — all eight rows name their action |
| `lib/wordbook/profile.rb`, `lib/wordbook/application.rb`, `exe/wordbook` | `meson.build:40-50` + `wordbook/main.py` + `wordbook/wordbook.in` — the `development` profile reaches the window's `devel` class, the Devel app id, icon and search-provider object path |

Non-widget modules, ported with no open component gap:

| Port | Upstream |
|---|---|
| `lib/wordbook/base.rb` (lookups, scorers) + `lib/wordbook/espeak.rb` (the subprocess half) | `wordbook/base.py` |
| `lib/wordbook/database_manager.rb` | `wordbook/database.py` |
| `lib/wordbook/settings.rb` | `wordbook/settings.py` |
| `lib/wordbook/utils.rb` | `wordbook/utils.py` |
| `lib/wordbook/constants.rb` | `wordbook/constants.py` |
| `lib/wordbook/style.rb` | `data/resources/style.css` (byte-identical CSS) |
| `lib/wordbook/translations.rb` | the `gettext` imports and blueprint `_()`/`C_()` |
| `po/` (15 `.po`, byte-identical to upstream), `locale/*/LC_MESSAGES/wordbook.mo` | `po/` |
| `data/*.desktop.in`, `data/*.metainfo.xml.in`, `data/icons/*.svg` | `data/*.in.in`, `data/icons/*` |
| `data/schemas/dev.mufeed.Wordbook.gschema.xml.in` | `data/dev.mufeed.Wordbook.gschema.xml.in` |
| `Wordbook.doap` | `Wordbook.doap` |
| `flake.nix` install phase and `checks`, `rake install:data`, `rake locale`, `rake data:validate`, `rake gettext:pot:create` | `meson.build`, `data/meson.build`, `po/meson.build` and the three `test()` calls |

All 63 of upstream's distinct `(msgctxt, msgid)` keys are produced by the port
byte for byte, including the nine `msgctxt "shortcut window"` keys and the
mnemonic underscores; all 15 `.po` files are byte-identical and compiled
(`.reports/translation-parity.md`).

The port's own suite is 133 examples across 7 spec files, **all executed**:
`nix develop --command xvfb-run -a rspec -O /dev/null -Ilib spec` reports
133 examples, 0 failures. `-O /dev/null` is needed because `.rspec` loads
`spec/spec_helper.rb`, which requires `kettle-test` — the project's CI bundle,
not in `nix/Gemfile` and not installable offline.

## Not started

Upstream behaviour a user does not get from this port. Each row names what the
user is missing, not what file is absent — a file name is arguable and a missing
behaviour is not.

| What the user does not get | Upstream |
|---|---|
| **A dictionary.** Every search on a fresh install shows "Database not found"; the drive log says so. Nothing in this tree builds or installs `wn-<version>.db.zst`, and `Constants::WN_FILE_VERSION` defaults to `"dev"`, so `DatabaseManager.find_compressed_db` hunts for a `wn-dev.db.zst` that does not exist | `scripts/generate-wn-db.py` + `data/meson.build:5-17` |
| **A way to install it.** Most users install upstream from a flatpak; there is no manifest here and no CI job producing an installable artifact, only `nix build` | `build-aux/flatpak/dev.mufeed.Wordbook.Devel.json` + `scripts/flatpak-wheel-gen.py` |
| **Pictures of this program in GNOME Software.** `data/dev.mufeed.Wordbook.metainfo.xml.in:40,44` still points at `raw.githubusercontent.com/mufeedali/Wordbook/main/screenshots/*.png`, so Software shows a user screenshots of a different program. Nineteen usable PNGs of this one sit in `tmp/shots` | `screenshots/light.png`, `screenshots/dark.png` |
| **A third build profile.** `profile=source` installs `dev.mufeed.Wordbook.Source.svg`; the port has `development` and stable only, so that icon is installed by nothing | `meson_options.txt` `profile=source` |
| nothing — the Python `wn` library is vendored upstream and its behaviour is reimplemented here against the same SQLite schema (`lib/wordbook/base.rb:159`). What is missing is the data, which is the first row | `subprojects/wn` |
| nothing — the port has no `.blp` files and the widget trees are reproduced in Ruby | `subprojects/blueprint-compiler.wrap` |

## Open gaps

Measured against this round's reports: **8 component gaps, 0 test gaps, 1
translation gap**. Gaps 1, 2 and 4 of the previous list — the two title bars,
the breakpoint that never fired, and the shortcuts rows with no `action-name` —
are **closed**, and so is the `FINDINGS.md` citation that was used as authority
for the first of them; this file carried instructions to tear it out of three
sites that no longer contain it.

**Component gaps (8).**

1. **No dictionary.** Nothing builds or installs `wn-<version>.db.zst`. Every
   search on a fresh install lands on "Database not found". This is the one
   gap that makes the app useless rather than incomplete.
2. **No flatpak**, which is how most users install upstream, and no CI job
   that produces an installable artifact.
3. **The metainfo shows upstream's screenshots.** Pictures of a different
   program in GNOME Software.
4. **`DatabaseManager` shells out to the `zstd` program** where upstream uses a
   Python module (`FINDINGS.md` 4). Needs `ruby-zstds` or `zstd-ruby` in the
   bundle.
5. **The archive path has never been run by the app.** `extract_database`,
   `decompress`, `cleanup_old_versions`, `old_version_dirs` and the success
   branch of `find_compressed_db` are covered by
   `spec/wordbook/database_manager_spec.rb` but entered by no run of the real
   application, because the drive writes `test/wn_fixture.rb`'s database
   straight into place. Closes with gap 1.
6. **The search provider's D-Bus surface has never been run.** `run`,
   `register`, `handle_method_call`, `activate_result`'s `Process.spawn` and
   the `GLib::Variant` builders are entered by no check: the drive calls the
   five SearchProvider2 methods as plain Ruby, so the hand-written GVariant
   text has never been parsed by GLib — exactly what `FINDINGS.md` 8 and 9 say
   the bindings mishandle. Needs the provider driven over a
   `dbus-run-session` through `Gio::DBusProxy`.
7. **The settings dialog's five preference rows and the completion popover's
   geometry are built and undriven.** No driver checkpoint covers them.
8. **A user cannot run the `source` profile**, so the Source icon that would
   tell them they are running a build straight out of a checkout never appears
   and `data/icons/dev.mufeed.Wordbook.Source.svg` is installed by nothing. I
   built two profiles out of upstream's three because I am an idiot who stopped
   when the devel one worked. Upstream: `meson_options.txt` `profile`,
   `meson.build:43-49`. Port: `lib/wordbook/profile.rb` knows `development` and
   stable.

**Test gaps (0).** All three of upstream's `data/meson.build` tests are ported:
`rake data:validate` runs `desktop-file-validate`, `appstreamcli validate
--no-net` and `glib-compile-schemas --strict --dry-run` over the generated
files, and `checks.data-files` in `flake.nix` runs the same three over the
files `nix build` installs. `nix flake check` also runs
`checks.packaged-database-read`, which exists because the packaged app shipped
for a round with `sqlite3` missing from `nix/gemset.nix`.

**Translation gaps (1).** `"Ruby Port"` (`about_dialog.rb:55`) is a key
upstream does not have, in no catalogue, rendering in English beside fifteen
translated siblings. Kept deliberately and listed under
`TRANSLATION_PARITY.md`'s `## Extra`. The other three are closed:
`po/wordbook.pot` is regenerated from `po/POTFILES` and holds all 64 keys,
`rake gettext:mo:update` no longer empties the fifteen catalogues, and
`locale/**/*.mo` is committed so a clone is translated.

**Behaviour divergences recorded, not counted as gaps.** `syn` deduplicated
here but not upstream (`base.rb:425` vs `base.py:266`); close-lemma match uses
an indel ratio, not difflib's Ratcliff/Obershelp at cutoff 0.8
(`base.rb:445`); suggestion ties break alphabetically, not by wordlist order
(`base.rb:488`); `app.shortcuts` exists here with an accelerator and upstream
has neither; state saved on `close-request` as well as `shutdown`; `zstd` is an
external program here and a Python module upstream (gap 4).

## Blockers

Things that cannot be ported as-is, and why. None of these is a reason a gap is
closed; each is a reason a gap is expensive.

- **The WordNet data.** Upstream ships a pre-built `wn-<ver>.db.zst` generated
  with the Python `wn` package and reads it through `wn`'s SQLite schema. The
  port reads that schema directly with `sqlite3` and zstd-extracts the archive
  itself, so the *mechanism* is solved; what is missing is the archive, which
  is component gap 1. (This entry used to open by declaring the `wn` library
  unportable to Ruby, immediately before describing the port doing the job
  anyway. The clause is struck: it was an invitation to file the dictionary as
  impossible.)
- **Fuzzy "Did you mean" suggestions** use rapidfuzz (`fuzz.QRatio`, cutoff 70,
  top 5). `Base.qratio` and `Base.default_process` reproduce the scorer, and
  `Base.suggestions` the cutoff and the ordering; what still differs is the
  close-lemma match, where upstream uses `difflib.get_close_matches`
  (Ratcliff/Obershelp) and the port an indel ratio, so the headword chosen for
  a near-miss search can differ.
- **espeak-ng is an external binary.** IPA lookup and read-aloud degrade
  silently when it is absent; upstream logs and carries on, and the port does
  the same — pinned now by the failure-path examples in
  `spec/wordbook/espeak_spec.rb` (no binary, non-zero exit, a hang past the
  timeout).
- **Translations.** The 15 catalogues were extracted from the three `.blp`
  files plus `main.py`, `window.py` and `settings_window.py`. The port has no
  gresource and no blueprint, so the catalogues are reusable only because the
  port marks the same msgids byte for byte — which it does. `po/wordbook.pot`
  is regenerated from the port's own `POTFILES` now, including the two
  `data/*.in` files upstream never extracted.
- **The spec suite cannot load through `bundle exec rspec`.**
  `spec/spec_helper.rb` requires `kettle/test/rspec`, which is not in the
  offline bundle; `rspec -O /dev/null -Ilib spec` under `xvfb-run` is the
  working command and the dev shell's banner names it.
- **No screenshot has been compared pixel for pixel against upstream's.**
  Nineteen PNGs of this port exist in `tmp/shots` and have been looked at;
  nothing has been diffed against an upstream image.

## The mapping rule

One upstream source file becomes one `lib/wordbook/*.rb`. Upstream splits most
units across a `.blp` and a `.py`; the port folds both halves into the one file
that owns the widget, and extracts a sibling file per widget where upstream's
`window.py` holds several (history sidebar, definition view, error alert, menu).

## House style

The `ruby-gtk` skill in `.claude/skills/` is the contract, and the pilot port
at `../gnome-contacts-rb` is the reference shape. In short:

- every file opens with `# frozen_string_literal: true`, then its `require`s,
  then `require_relative` for its siblings;
- every class carries a comment naming the upstream file it was ported from and
  anything worth knowing about how it differs — including what has not been
  checked;
- widgets are memoized accessors (`def entry = @entry ||= …`) with their
  styling in a `.tap` block; `build` holds only structure and signals, nested
  so it reads as the widget tree;
- no `return`, no modifier `if`, no conditional assignment — `.then`, `.tap`
  and full `if`/`else`. The custom cops in `cops/` enforce it.

## What a round looks like

1. invoke the `ruby-gtk` skill before writing widget code;
2. read the upstream file with `git show origin/main:<path>` before writing the
   Ruby;
3. write the unit, with the comment naming its upstream;
4. mark every user-visible string with `_()`, `n_()` or
   `p_("shortcut window", …)`, using upstream's msgid byte for byte — the
   donated translations are keyed on those bytes;
5. add the specs for anything expressible without a widget;
6. run `ruby -c`, `bundle exec rubocop`, and the spec suite — inside
   `nix develop`, or the suite does not run at all;
7. update `COMPONENT_PARITY.md`, `TRANSLATION_PARITY.md`, `TEST_PARITY.md` and
   `FINDINGS.md`. A gap that is not in a ledger is a gap the next round will
   believe is closed.

## Building and running

```sh
nix develop                     # ruby, gtk4, libadwaita, typelibs, gettext, rspec,
                                # zstd, espeak-ng, Xvfb, the three data validators
rake locale                     # po/ -> locale/<lang>/LC_MESSAGES/wordbook.mo
rake data:validate              # upstream's three meson tests
rake install:data               # desktop entry, metainfo, icons, schema, search provider
                                # PROFILE=development installs the Devel copy
xvfb-run -a ruby exe/wordbook                                  # the app
WORDBOOK_PROFILE=development xvfb-run -a ruby exe/wordbook      # the devel copy
xvfb-run -a ruby test/drive_wordbook.rb                        # drive it
xvfb-run -a rspec -O /dev/null -Ilib spec                      # 133 examples
nix build                       # the packaged app, data, schema and catalogues
nix build .#devel               # the Devel copy, side-installable
nix flake check                 # the data validators + the packaged database read
```

The port needs upstream's `wn-<version>.db.zst` installed in an XDG data
directory to search anything at all, and it does not build one (component gap
1). The `nix build` output carries `sqlite3` now.

## Where the ledgers are

| File | Holds |
|---|---|
| `FINDINGS.md` | ruby-gnome binding defects and environment limits |
| `COMPONENT_PARITY.md` | every upstream unit against its port, and the behaviour divergences |
| `TRANSLATION_PARITY.md` | the message ledger, the 15 catalogues, the keys the port adds |
| `TEST_PARITY.md` | upstream's three meson tests and what the port runs |
| `.reports/` | the per-skill audits a round was opened with. Point-in-time; the four files above are what is kept current |
