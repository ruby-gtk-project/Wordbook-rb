# Porting Wordbook to Ruby

Resume point for the next run. Factual; every claim below is either read out of
`origin/main`, read out of `lib/`, or quoted from a report in `.reports/`.
Nothing in this port has ever been rendered — `require "gtk4"` raises
`Gtk::InitError` in the environment it was written in (`FINDINGS.md` 5), so
every parity verdict is source against source.

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` (Python/PyGObject + Blueprint + meson) |
| Port | `ruby` branch (Ruby 3.4, `gtk4`/`adwaita` gems, gem layout) |
| Upstream as spec | read with `git show origin/main:<path>`; never checked out, never merged |
| Units mapped | 11 / 11 |
| Units with no gap on any axis | 7 / 11 |
| Units verified on screen | 0 / 11 |
| Open gaps | 17 |

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

Implemented and believed complete on all four axes (widget set, properties,
signals, strings), per `.reports/component-parity.md`. None has been seen to
render.

| Port | Upstream |
|---|---|
| `lib/wordbook/main_menu.rb` | `data/resources/ui/window.blp:4-42` (`menu app-menu`) |
| `lib/wordbook/definition_view.rb`, `definition_row.rb`, `relation_box.rb`, `pronunciation_row.rb` | `ui/window.blp:224-236` + `_populate_definitions` / `_create_*` in `wordbook/window.py` |
| `lib/wordbook/settings_dialog.rb` | `ui/settings-window.blp` + `wordbook/settings_window.py` |
| `lib/wordbook/about_dialog.rb` | `on_about` in `wordbook/main.py` |
| `lib/wordbook/error_dialog.rb` | `_new_error` in `wordbook/window.py` |
| `lib/wordbook/search_completion.rb` | `wordbook/search_completion.py` |
| `lib/wordbook/shell_search_provider.rb`, `exe/wordbook-search-provider`, `data/dev.mufeed.Wordbook.SearchProvider.ini`, `.service.in` | `data/search_provider.in` + `data/dev.mufeed.Wordbook.SearchProvider.ini` |

Written and working but **carrying open gaps** (details under Open gaps):

| Port | Upstream | Gap |
|---|---|---|
| `lib/wordbook/window.rb` | `ui/window.blp` (template) + `wordbook/window.py` | gaps 1, 2 |
| `lib/wordbook/history_sidebar.rb`, `history_row.rb`, `history_object.rb` | `ui/window.blp:61-145` + history half of `window.py` | gap 3 |
| `lib/wordbook/shortcuts_dialog.rb` | `ui/shortcuts-dialog.blp` | gap 4 |
| `lib/wordbook/application.rb`, `exe/wordbook` | `wordbook/main.py` + `wordbook/wordbook.in` | gap 5 |

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
| `flake.nix` install phase, `rake install:data`, `rake gettext:mo:update` | `meson.build`, `data/meson.build`, `po/meson.build` |

All 63 of upstream's distinct `(msgctxt, msgid)` keys are produced by the port
byte for byte, including the nine `msgctxt "shortcut window"` keys and the
mnemonic underscores; all 15 `.po` files are byte-identical and compiled
(`.reports/translation-parity.md`).

The port's own suite is 118 examples across 7 spec files. **None was executed
in the last audit** — `bundle exec rspec` is unavailable outside `nix develop`
in that checkout, and the last recorded run is 28 examples out of date.

## Not started

Upstream components with no Ruby counterpart at all:

| Upstream | What it is |
|---|---|
| `scripts/generate-wn-db.py` + `data/meson.build:5-17` | builds and installs `wn-<version>.db.zst`, the dictionary the app reads |
| `data/dev.mufeed.Wordbook.gschema.xml.in` | GSettings schema, installed to `share/glib-2.0/schemas` |
| `build-aux/flatpak/dev.mufeed.Wordbook.Devel.json` | the flatpak manifest, built by upstream CI on every push |
| `Wordbook.doap` | GNOME project metadata |
| `screenshots/light.png`, `screenshots/dark.png` | the images the shipped metainfo points at |
| `meson_options.txt` `profile=development` wiring | the `Devel` app id, icon, object path and `development_mode` flag |
| the three `test()` calls in `data/meson.build` | upstream's whole suite (desktop-file-validate, appstreamcli validate, glib-compile-schemas --strict) |
| `subprojects/wn` | the Python `wn` library upstream vendors |
| `subprojects/blueprint-compiler.wrap` | owes the port nothing: the port has no `.blp` files, and the widget trees are reproduced in Ruby |

## Open gaps

The last audit (`.reports/` @ `b5f105c`) reported **17 gaps, clean=false**: 14
in `component-parity.md` and 3 in `test-parity.md`. `translation-parity.md`
reports 3 further gaps and `accountability-ensurance.md` 6 unrewritten hits.

**Component gaps (14).**

1. **The window has two title bars.** `lib/wordbook/window.rb:847` builds
   `Gtk::ApplicationWindow.new(@app)` with no `set_titlebar` anywhere in
   `lib/`, so GTK draws its default titlebar above the Adwaita header bar —
   two bars, two close buttons, where `window.blp:44`'s
   `Adw.ApplicationWindow` has one. The reason recorded for the substitution
   (`FINDINGS.md` defect 2, "`Adwaita::ApplicationWindow` cannot be
   constructed") is **false**: `grep -rn "Adwaita.init" lib exe spec` returns
   nothing, and the pilot port constructs the widget after calling it
   (`gnome-contacts-rb/lib/main.rb:196-211`). The false claim is cited as
   authority from `window.rb:36-40`, `window.rb:841-845` and
   `COMPONENT_PARITY.md:40` and must be torn out of all of them.
2. **The sidebar does not collapse.** `window.blp:53-59` declares an
   `Adw.Breakpoint` on `max-width: 550sp`, re-evaluated on every allocation.
   `window.rb:427-430` drives `update_collapse` from `notify::default-width`,
   `notify::maximized`, `notify::fullscreened`, `map` and
   `notify::gtk-xft-dpi`, none of which fires on an ordinary user resize. The
   `550sp` scaling arithmetic is correct; the trigger is the gap. Blocked only
   by gap 1.
3. **The favourites filter button fires no action.** `window.blp:78` gives it
   `action-name: "win.toggle-favorites"`; `history_sidebar.rb:58` connects
   `toggled` and `:128` flips `active` by hand, so the button reports no action
   to AT-SPI and two code paths must be kept in step.
4. **The shortcuts rows name no action.** `shortcuts-dialog.blp` puts
   `action-name` on all eight items; `shortcuts_dialog.rb:70` passes literal
   accelerators from `Application::APP_ACCELS`, so a rebind elsewhere is
   invisible and the rows expose no action to AT-SPI.
5. **There is no development build.** `application.rb:45` hardcodes
   `APP_ID = "dev.mufeed.Wordbook"` and nothing passes `app_id:` or
   `development_mode:`. The `devel` CSS class at `window.rb:854` is
   unreachable, `data/icons/…Devel.svg` is installed nowhere
   (`flake.nix:172`), and the search provider `.ini` hardcodes the stable
   object path.
6. **The app ships no dictionary.** Nothing builds or installs
   `wn-<version>.db.zst`; `Constants::WN_FILE_VERSION` defaults to `"dev"`, so
   `DatabaseManager.find_compressed_db` hunts for a `wn-dev.db.zst` that does
   not exist and every search shows "Database not found".
7. **The GSettings schema is not shipped.** No `data/*.gschema.xml*` exists;
   `flake.nix:205` globs `data/schemas/*.gschema.xml`, a directory that does
   not exist, so the compile step silently does nothing.
8. **There is no flatpak**, which is how most users install upstream.
9. **`Wordbook.doap` is not ported**, so GNOME infrastructure has no record of
   the project.
10. **The metainfo points at upstream's screenshots** —
    `raw.githubusercontent.com/mufeedali/Wordbook/main/screenshots/*.png`,
    pictures of a different program. The port ships no `screenshots/` and
    could not produce one: it has never been on screen.
11-13. **The three upstream tests**, see below.
14. `subprojects/blueprint-compiler.wrap` — recorded for completeness; the only
    upstream file that owes the port nothing.

**Test gaps (3).** 0 of 3 upstream tests ported. `data/meson.build:36,58,76`
declare `Validate desktop file`, `Validate appstream file` and
`Validate schema file`, and `.github/workflows/CI.yml:26` runs them via
`run-tests: "true"`. The port has no counterpart for any of them, and gap 7
leaves the third with nothing to validate. The port's hand-rolled substitution
and `msgfmt --desktop`/`msgfmt --xml` merges (`flake.nix:180-186`) make the
first two more necessary than upstream's, not less. Closing all three needs no
display: three shell invocations over built files, as a rake task plus a CI job.

**Translation gaps (3).** `po/wordbook.pot` is upstream's file verbatim, not
regenerated from the port's `POTFILES`, so it describes the wrong program; and
the port invents two keys (`"Did you mean: %s?"` wording and `"Ruby Port"`).

**Accountability hits (6, none rewritten).** `FINDINGS.md` defect 2 (false, see
gap 1), defect 1 (unverified consequence assessment), `PORTING.md`'s former
four-omissions-in-one-sentence line (replaced by the Not started table above),
the `a73a55a` test-parity false clean (corrected), and three stale counts
presented as current (`FINDINGS.md:108` "the other 90 examples run and pass";
`.reports/component-inventory.md:8-12` "`lib/` holds three files today", when it
holds 26).

**Behaviour divergences recorded, not counted as gaps.** `syn` deduplicated
here but not upstream (`base.rb:425` vs `base.py:266`); close-lemma match uses
an indel ratio, not difflib's Ratcliff/Obershelp at cutoff 0.8
(`base.rb:445`); suggestion ties break alphabetically, not by wordlist order
(`base.rb:488`); `app.shortcuts` exists here with an accelerator and upstream
has neither; state saved on `close-request` as well as `shutdown`; `zstd` is an
external program here and a Python module upstream (`database_manager.rb:107`);
`sqlite3` is absent from `nix/gemset.nix`, so the `nix build` output raises
`LoadError` on the first search (`FINDINGS.md` 6).

## Blockers

Things that cannot be ported as-is, and why.

- **The WordNet data.** Upstream ships a pre-built `wn-<ver>.db.zst` generated
  with the Python `wn` package and reads it through `wn`'s SQLite schema. No
  Ruby equivalent of `wn` exists, so the port must query that schema directly
  with `sqlite3` and zstd-extract the archive itself. Nothing is searchable
  until this is solved; it is also gap 6.
- **Fuzzy "Did you mean" suggestions** use rapidfuzz (`fuzz.QRatio`, cutoff 70,
  top 5). There is no Ruby drop-in, so the suggestion set will not match
  upstream exactly (divergences B and C).
- **espeak-ng is an external binary.** IPA lookup and read-aloud degrade
  silently when it is absent; upstream logs and carries on, and the port does
  the same.
- **Translations.** The 15 catalogues were extracted from the three `.blp`
  files plus `main.py`, `window.py` and `settings_window.py`. The port has no
  gresource and no blueprint, so the catalogues are reusable only because the
  port marks the same msgids byte for byte — which it does today. The `.pot`
  itself still cannot be regenerated from upstream's POTFILES.
- **No GSettings to port.** `dev.mufeed.Wordbook.gschema.xml.in` declares an
  empty schema and all state lives in `~/.config/wordbook/wordbook.json`. The
  file still has to be shipped (gap 7) so upstream's third test has something
  to validate and the next key added upstream has somewhere to land.
- **`app.shortcuts` is never registered in upstream's Python.** It comes from
  libadwaita auto-loading `shortcuts-dialog.ui` from the gresource base path.
  With no gresource the port must install the action and present the dialog
  itself, which it does — hence divergence D.
- **The `devel` CSS class** depends on meson's build-time `development_mode`
  flag. The port has no equivalent build switch (gap 5).
- **Nothing can be verified on screen in the authoring environment.**
  `require "gtk4"` raises `Gtk::InitError` there, so no widget in `lib/` has
  ever been instantiated and `spec/wordbook/application_spec.rb` and
  `shell_search_provider_spec.rb` cannot even load.
  `.claude/skills/ruby-gtk-testing` with `scripts/gtk_driver.rb` is installed
  and unused.

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
nix develop                     # ruby, gtk4, libadwaita, typelibs, gettext, rspec
rake gettext:mo:update          # po/ -> locale/<lang>/LC_MESSAGES/wordbook.mo
rake install:data               # desktop entry, metainfo, icons, search provider
ruby -Ilib exe/wordbook
nix build                       # the packaged app, data and catalogues included
```

The port needs upstream's `wn-<version>.db.zst` installed in an XDG data
directory to search anything at all; it does not build one, and the `nix build`
output is additionally missing the `sqlite3` gem.

## Where the ledgers are

| File | Holds |
|---|---|
| `FINDINGS.md` | ruby-gnome binding defects and environment limits. Defect 2 is known false (gap 1) and defect 1 is unverified; neither has been rewritten |
| `COMPONENT_PARITY.md` | every upstream unit against its port, and the behaviour divergences. Unit 1 still records gap 1 as a correspondence |
| `TRANSLATION_PARITY.md` | the message ledger, the 15 catalogues, the keys the port adds |
| `TEST_PARITY.md` | upstream's three meson tests and what the port runs |
| `.reports/` | the per-skill audits a round was opened with. Point-in-time; the four files above are what is kept current |
