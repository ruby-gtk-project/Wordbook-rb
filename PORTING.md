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
| The port's own suite | **160 examples, 0 failures**, executed |
| The driver | **`test/drive_wordbook.rb`**, **215 checks, 0 failures**, 19 screenshots into `tmp/shots` |
| Upstream tests ported | **3 / 3** (`rake data:validate` and `nix flake check`) |
| Open gaps | **1 component, 0 test, 1 translation** |

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
| `lib/wordbook/lmf_reader.rb`, `lib/wordbook/database_builder.rb`, `lib/wordbook/lexicon_download.rb`, `exe/wordbook-generate-db`, `rake wn:db` | `scripts/generate-wn-db.py` + the vendored `subprojects/wn` loader + `data/meson.build:5-17` |
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

The port's own suite is 160 examples across 9 spec files, **all executed**:
`nix develop --command xvfb-run -a rspec -O /dev/null -Ilib spec` reports
160 examples, 0 failures. `-O /dev/null` is needed because `.rspec` loads
`spec/spec_helper.rb`, which requires `kettle-test` — the project's CI bundle,
not in `nix/Gemfile` and not installable offline.

## Not started

Upstream behaviour a user does not get from this port. Each row names what the
user is missing, not what file is absent — a file name is arguable and a missing
behaviour is not.

| What the user does not get | Upstream |
|---|---|
| **A pre-built dictionary.** `rake wn:db` builds and `rake install:data`/`nix build` install `wn-<version>.db.zst` when one has been built, exactly as upstream's `-Dinstall_wn_db` does, but neither this tree nor a release of it carries one — it is a 60 MB build product on both sides, `.gitignore`d here (`/data/wn-*.db.zst`) the same way it is untracked upstream. **Run for real this round**: `rake wn:db` downloaded the real 2025 lexicon and `DatabaseBuilder` wrote a 73.9 MB database (161,875 entries) compressed to 23.6 MB, and the full app path — `DatabaseManager.setup` through `Base.get_definition` — read a real definition and IPA back out of it. See "Open gaps" below | `scripts/generate-wn-db.py` + `data/meson.build`'s `install_wn_db` option |
| nothing — the Python `wn` library is vendored upstream, and both halves of what the app needs from it are reimplemented here: reading its SQLite schema (`lib/wordbook/base.rb:159`) and writing it from the WN-LMF lexicon (`lib/wordbook/database_builder.rb`) | `subprojects/wn` |
| nothing — the port has no `.blp` files and the widget trees are reproduced in Ruby | `subprojects/blueprint-compiler.wrap` |

## Open gaps

Measured against this round's own re-check of every gap this file has ever
listed, against the files and commands each one names: **1 component gap, 0
test gaps, 1 translation gap**. An older round's intro paragraph used to live
here reciting which of a previous list's 8 gaps had closed; the list itself
had moved on to a different 8 since, with most of those closed too and still
reported open, so the paragraph is gone rather than extended again — the gap
list below is now the only place a gap's state is recorded, checked against
source this round rather than carried forward from the last report that
mentioned it.

**Component gaps (1).** This section listed 8 for several rounds; this round
re-checked each one against the files it names, not against the sentence
describing it, and 7 were already closed — some since several rounds back —
while the ledger kept reporting them open, which is exactly the staleness this
file's own header warns about. Corrected below, with what closed each one and
where that is recorded.

1. **No dictionary ships pre-built**, so a fresh install with no WordNet
   archive placed next to it lands every search on "Database not found".
   This is not a defect: upstream does not ship one either —
   `meson_options.txt`'s `install_wn_db` is a meson option, off by default,
   and `data/meson.build:4-16`'s `custom_target` only builds one when a build
   asks for it. The port's equivalent is `rake wn:db`, run once per install
   the same way upstream's custom target runs once per configured build.
   **Run for real this round**, not just against the spec suite's four-entry
   fixture: `nix develop --command rake wn:db` downloaded
   `english-wordnet-2025-plus.xml.gz` from the real GitHub release URL and
   `DatabaseBuilder` wrote a 73.9 MB SQLite database (161,875 entries, 212,659
   senses, 120,564 synsets) compressed to 23.6 MB. Then, with
   `MESON_BUILD_ROOT=.` so `DatabaseManager.candidates` found it under
   `data/`, the full real path ran end to end with no fixture involved:
   `DatabaseManager.needs_extraction?` → `.setup` → `extract_database` →
   `Zstd::StreamingDecompress` → `Base.wordnet` → `Base.get_definition
   ("serendipity", wn)`, which returned the real definition
   ("good luck in making unexpected and fortunate discoveries") and IPA
   (`ˌsɛ.ɹən.ˈdɪ.pɪ.ti`) read out of the real database. This is what gap 5
   below used to ask for; it closes with this entry, not separately. The
   23.6 MB archive and the extracted copy under `~/.local/share/wordbook` are
   build/runtime products, correctly `.gitignore`d (`/data/wn-*.db.zst`), and
   were deleted after the check rather than committed — a user or a packager
   runs `rake wn:db` themselves, the same as upstream's build asks a packager
   to run `meson configure -Dinstall_wn_db=true`.

Closed, found already done this round, with where that is recorded:

- **No flatpak** — closed: `build-aux/flatpak/dev.mufeed.Wordbook.Devel.json`
  and `.github/workflows/ci.yml`'s `flatpak-builder` job both exist and build
  on every push. `COMPONENT_PARITY.md`'s "Files with nothing opposite them"
  table.
- **The metainfo shows upstream's screenshots** — closed:
  `data/dev.mufeed.Wordbook.metainfo.xml.in`'s four `<image>` tags point at
  `raw.githubusercontent.com/ruby-gtk-project/Wordbook-rb/ruby/screenshots/*`,
  this port's own committed PNGs, read directly out of the file this round.
- **`DatabaseManager` shells out to `zstd`** — closed: `zstd-ruby`,
  `FINDINGS.md` 4, read directly out of `lib/wordbook/database_manager.rb`
  this round, which has no `Process.spawn` or backtick call in it.
- **The archive path has never been run by the app** — closed this round,
  for real, not by assertion: see gap 1 above.
- **The search provider's D-Bus surface has never been run** — closed:
  `test/drive_search_provider_dbus.rb` calls all five `SearchProvider2`
  methods over a private session bus with `gdbus call`, a real client over a
  real socket. `COMPONENT_PARITY.md` Unit 10, `FINDINGS.md` 17.
- **The settings dialog's rows and the completion popover's geometry are
  undriven** — closed: `test/drive_wordbook.rb`'s "the preferences dialog
  opens" through "flipping the switches writes the settings" steps drive all
  five rows, and "the completion popover lists the wordlist's matches" reads
  `pointing_to` off the popover.
- **A user cannot run the `source` profile** — struck, not closed: there is
  no `source` profile. Checked against `origin/main` this round —
  `meson_options.txt`'s `profile` option has exactly two choices, `default`
  and `development`; `data/icons/meson.build` installs only
  `application_id + '.svg'`, which is one or the other. Upstream never
  installs `dev.mufeed.Wordbook.Source.svg` either; nothing in its build
  references the file by name. The port's two profiles
  (`lib/wordbook/profile.rb`) already match upstream's two exactly.

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
has neither; state saved on `close-request` as well as `shutdown`.

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
xvfb-run -a rspec -O /dev/null -Ilib spec                      # 160 examples
nix build                       # the packaged app, data, schema and catalogues
nix build .#devel               # the Devel copy, side-installable
nix flake check                 # the data validators + the packaged database read
```

The port needs a `wn-<version>.db.zst` installed in an XDG data directory to
search anything at all, and neither this tree nor `nix build`'s default
output carries one — `rake wn:db` has to be run first, which is component gap
1 below, and is exactly what `-Dinstall_wn_db` asks a packager to do upstream.
The `nix build` output carries `sqlite3` now.

## Where the ledgers are

| File | Holds |
|---|---|
| `FINDINGS.md` | ruby-gnome binding defects and environment limits |
| `COMPONENT_PARITY.md` | every upstream unit against its port, and the behaviour divergences |
| `TRANSLATION_PARITY.md` | the message ledger, the 15 catalogues, the keys the port adds |
| `TEST_PARITY.md` | upstream's three meson tests and what the port runs |
| `.reports/` | the per-skill audits a round was opened with. Point-in-time; the four files above are what is kept current |
