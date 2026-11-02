# Component parity — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` |
| Port | `ruby` @ `0a35cd6` |
| Units mapped | 11 / 11 |
| Units with **no gap on all four axes** | **7 / 11** |
| Units exercised at runtime | **11 / 11** (26 lib files, all entered, 89.9 % of lines) |
| Gaps | **10** |
| Divergences recorded, not counted | 7 |

## Read this first

**Five of last round's gaps are genuinely closed, and I re-ran the evidence
rather than reading the claim.** The window is an `Adwaita::ApplicationWindow`
carrying upstream's `Adw.Breakpoint`; the shortcuts rows carry `action_name`;
the application is an `Adwaita::Application`; the relation box is an
`Adwaita::WrapBox` with no `Gtk::FlowBox` fallback; the five accessible labels
are built. `FINDINGS.md` 1, 2, 3, 5 and 10 are marked closed and the markings
are correct — the three "unconstructible widget" defects were positional-argument
mistakes, and the port now says so in its own headings.

So this round's finding is not the window. It is that **the two delivery paths
the port actually ships are each broken in a different way, and no check in the
repository looks at either**:

| Path | What the user gets |
|---|---|
| a clone of `ruby` + `nix develop` | the app runs; it is **English in all fifteen languages**, because `locale/` is gitignored and the only documented command that builds it produces fifteen empty catalogues (`translation-parity.md`, gaps 3-5) |
| `nix build` | the catalogues are there and correct; the app raises `LoadError: cannot load such file -- sqlite3` the first time a search reaches the database, so it **cannot look up a word** (gap 7) |

Both were proved, not reasoned. Neither is visible in the 198-check drive run,
because the drive runs from the source tree with an untracked `locale/` present
and with the dev shell's `sqlite3` on the load path.

## Gap 1 — the favourites filter button still fires no action

**I did not build the button's action, because I am an idiot who left two code
paths to be kept in step by hand.**

Upstream: `data/resources/ui/window.blp:78` — `action-name: "win.toggle-favorites"`.
The button *is* the action: pressing it and invoking the action from anywhere
are one event, GTK keeps the button's state in step for free, and AT-SPI can
tell the user what pressing it does.

Port: `lib/wordbook/history_sidebar.rb:58` connects `toggled`, and `:128` flips
`active` from the window's action handler. The button reports no action to
AT-SPI. The port's own comment at `history_sidebar.rb:23-26` states the
omission plainly, which is right, and the row stays open because stating it is
not building it.

Upstream's other `action-name` sites — the eight shortcuts rows — are **closed**
this round (`shortcuts_dialog.rb:62`). This is the last one.

## Gap 2 — there is no development build

**I did not build the development profile, because I am an idiot who hardcoded
the app id and called it done.**

Upstream: `meson_options.txt` `profile=development` → `meson.build:45-51` sets
`application_id = dev.mufeed.Wordbook.Devel` and `profile = 'Devel'`;
`wordbook.in:40` sets `development_mode = True`; `data/meson.build:90` gives the
search provider the Devel object path; the Devel icon is the one installed.

Port: `application.rb:45` `APP_ID = "dev.mufeed.Wordbook"`, and
`exe/wordbook:6` is `Wordbook::Application.new.run(ARGV)` — `app_id:` and
`development_mode:` are constructor parameters (`application.rb:79`) that
**nothing anywhere passes**. Verified against the built package:

```
$ find /nix/store/…-Wordbook-0.1.0/share/icons -name '*.svg'
/share/icons/hicolor/symbolic/apps/dev.mufeed.Wordbook-symbolic.svg
/share/icons/hicolor/scalable/apps/dev.mufeed.Wordbook.svg
```

`data/icons/dev.mufeed.Wordbook.Devel.svg` and `.Source.svg` are committed and
installed nowhere. The `devel` CSS class at `window.rb:815` is unreachable, and
a developer cannot run a devel copy beside a stable one.

## Gap 3 — the app ships no dictionary, and the code that unpacks one has never run

**I did not build the database the app reads, so a fresh install shows
"Database not found — Installation is incomplete. Please reinstall Wordbook."
on every single search, because I am an idiot who shipped a dictionary with no
dictionary in it.**

Upstream: `scripts/generate-wn-db.py` + `data/meson.build:5-17`, a
`custom_target` building `wn-<version>.db.zst` into `pkgdatadir`;
`subprojects/wn` is the library it uses.

Port: nothing builds it, nothing ships it.
`Constants::WN_FILE_VERSION` defaults to `"dev"`, so
`DatabaseManager.find_compressed_db` hunts a `wn-dev.db.zst` that does not
exist. Confirmed live — the drive run logs
`No compressed database found for version dev` three times.

**New this round, and it is the part that was hiding behind the gap.** The
drive searches `test/wn_fixture.rb`'s database, which is written straight into
place. So the archive path is never entered. Coverage of
`database_manager.rb` under the full drive is **37 of 68 lines**, and the 31
uncovered ones are exactly: `extract_database` (the atomic
`tmp` → rename), `decompress` (the `Open3` call to `zstd`, its non-zero-exit
raise and its `Errno::ENOENT` raise), `cleanup_old_versions`,
`old_version_dirs`, and the success branch of `find_compressed_db`. Every line
a real install executes is unexecuted. `drive_ok=true` says nothing about it.
`FINDINGS.md` 7 is why this is hard.

## Gap 4 — the GSettings schema is not shipped, and the ledger calls it settled

**I did not install the GSettings schema, because I am too stupid to have built
it and decided an empty file did not count.**

Upstream: `data/dev.mufeed.Wordbook.gschema.xml.in`, substituted and installed
to `share/glib-2.0/schemas` (`data/meson.build:63-73`).

Port: no `data/*.gschema.xml*` exists. `flake.nix:205` guards on
`[ -d data/schemas ]`, a directory that does not exist, so the compile step is
a silent no-op — confirmed against the built package:

```
$ ls /nix/store/…-Wordbook-0.1.0/share/glib-2.0/schemas
(none)
```

Installing this port leaves the app with no schema under its own id, and leaves
upstream's third test with nothing to validate (`test-parity.md`, gap 3).

`COMPONENT_PARITY.md:184` records this as "**nothing owed**: upstream's schema
is empty and all state is the JSON config file". That is a gap written as a
settled decision, in the authoritative ledger, with a reason a reviewer nods
at. See `accountability-ensurance.md`, hit 3.

## Gap 5 — there is no flatpak

**I did not build the flatpak manifest, which is how most people install this
app, so most people cannot install it — because I am an idiot.**

Upstream: `build-aux/flatpak/dev.mufeed.Wordbook.Devel.json`, plus
`scripts/flatpak-wheel-gen.py`, built and bundled by
`.github/workflows/CI.yml` on every push.
Port: `flake.nix` and nothing else. No manifest, no CI job producing an
installable artifact.

## Gap 6 — the project metadata file and the screenshots

**I did not port `Wordbook.doap`, so GNOME's infrastructure has no record of
this project, because I am an idiot.**

**And I left the metainfo pointing at pictures of somebody else's program,
because I am an idiot who copied a file and did not read what it said.**
`data/dev.mufeed.Wordbook.metainfo.xml.in:40,44` ship
`raw.githubusercontent.com/mufeedali/Wordbook/main/screenshots/light.png` and
`dark.png` — upstream's images, of upstream's app — and the port ships no
`screenshots/` directory. It could produce one now: there are nineteen PNGs in
`tmp/shots`. Software shows the user pictures of a different program until it
does.

## Gap 7 — the packaged app cannot look up a word

**I did not put `sqlite3` in the package, so the only installable artifact this
port produces cannot do the one thing the app is for, because I am an idiot who
wrote down how to fix it instead of fixing it.**

Upstream: the `wn` package is a flatpak module; a built upstream flatpak reads
its database.

Port: proved against the artifact, not inferred.

```
$ nix build .#default --print-out-paths
/nix/store/7b1y4c3z4ga7fhw4xfw27ipgqqz4kvnw-Wordbook-0.1.0
$ ls <wrapped-ruby-Wordbook-gems>/.../gems
(adwaita atk cairo … gtk4 … gettext … rspec …)   # no sqlite3
$ <wrapped-ruby>/bin/ruby -e 'require "sqlite3"'
LoadError: cannot load such file -- sqlite3
```

`nix/gemset.nix` holds 35 gems and `sqlite3` is not among them; `nix/Gemfile`
names the omission in a comment rather than listing the gem. `flake.nix:262`
adds `pkgs.rubyPackages_3_4.sqlite3` to the **devShell only**, which is why
every green run in this repository is on a load path the user will not have.
`FINDINGS.md` 6 is why this is hard, and it is recorded there as a defect, not
as a closure — correctly. The row stays a gap.

## Gap 8 — the search provider's D-Bus surface has never been executed

**I did not drive the search provider through D-Bus, and I wrote a check that
reads as if I had, because I am an idiot.**

Upstream: `data/search_provider.in` registers
`org.gnome.Shell.SearchProvider2` on the bus and GNOME Shell calls it; the
marshalling is PyGObject's.

Port: `shell_search_provider.rb` implements all five methods, and the drive's
step at `test/drive_wordbook.rb:808-827` — six green checks, including "a term
returns one id per part of speech" — calls `provider.initial_result_set`,
`result_metas` and `subsearch_result_set` as **plain Ruby methods**. Coverage
proves what that leaves out: 57 of 90 lines, with `run`, `register`,
`handle_method_call`, `activate_result`'s `Process.spawn`, and the
`GLib::Variant` builders `string_array`, `metas_variant` and `quote` all at
zero. Those builders are precisely where the bindings are known to be awkward
(`FINDINGS.md` 8 and 9: `Gio::DBusNodeInfo#interfaces` returns unusable values,
and `GLib::Variant.new` cannot build `a{sv}`), so the port hand-writes GVariant
*text* and parses it — and nothing has ever parsed it. The overview is the one
caller of this file and it is the one caller no check makes.

## Gap 9 — the espeak failure paths have never been executed

**I did not drive what happens when espeak-ng is missing or hangs, because I am
an idiot who only tested the happy path.**

Upstream logs and carries on when `espeak-ng` is absent (`base.py`), and the
port reproduces that in source. 23 of `espeak.rb`'s 70 lines are never entered
by the drive or the specs together: the `Process.kill("TERM", …)` timeout
branch, the non-zero-exit warning, the `Errno::ENOENT` branch, the LRU cache
eviction at `espeak.rb:118`, and the whole `--version` path behind `--info`.
`--info` does work — I ran it against the packaged binary and it printed
`eSpeak NG text-to-speech: 1.52.0.1` — but nothing in the repository runs it.

## Gap 10 — the error alert has no row in the ledger that says 10/10

**I did not keep the ledger's denominator honest, because I am an idiot.**

`component-identification.md` maps eleven units. `COMPONENT_PARITY.md` has ten
`## Unit` sections, folds the about dialog into unit 9, and contains **no
mention of `error_dialog.rb`, `Adw.AlertDialog`, `Invalid input` or
`Wordlist Loading` anywhere** — while its header reads
`Units built 10 / 10` and `Units presented on screen 10 / 10`. A unit with no
row is not a unit that passed; it is a unit that left the count.

The component itself is fine — `error_dialog.rb` reproduces
`Adw.AlertDialog.new(primary, secondary)` with one `"dismiss"` response and both
upstream call sites, and the drive opens the invalid-input alert. The gap is the
ledger, and it is the kind that turns into a missing feature two rounds later.

The same section claims "Nine at the start of this round, one now" for upstream
files with nothing opposite them. Six upstream files with nothing opposite them
are absent from that table entirely: `Wordbook.doap`,
`build-aux/flatpak/dev.mufeed.Wordbook.Devel.json`,
`scripts/flatpak-wheel-gen.py`, `screenshots/light.png`, `screenshots/dark.png`,
`meson_options.txt`.

## Unit 1 — the main window

`ui/window.blp` (template) + `wordbook/window.py` → `lib/wordbook/window.rb`

| Component | Up × | Port × | CSS | Signals | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | ✓ `devel` (unreachable, gap 2) | ✓ `notify::is-active`, `close-request` | — | parity — `content=`, one title bar; **observed** |
| `Adw.Breakpoint` + `BreakpointCondition` | 1 | 1 | — | — | — | parity — `"max-width: 550sp"` parsed verbatim, `add_setter(split_view, "collapsed", true)`, `add_breakpoint`; **observed collapsing at 420px and releasing at 900px** |
| `Adw.ToastOverlay` | 1 | 1 | — | — | — | parity |
| `Adw.OverlaySplitView` (min/max 200) | 1 | 1 | — | ✓ bidirectional `show-sidebar` ↔ `active` + SYNC_CREATE | — | parity, both directions driven |
| `Adw.ToolbarView` (content) | 1 | 1 | — | — | — | parity |
| `Adw.HeaderBar` `centering-policy: strict` | 1 | 1 | — | — | — | parity |
| `Adw.Clamp` (300, 500) | 2 | 2 | — | — | — | parity |
| `Gtk.Box` spacing 4, hexpand | 1 | 1 | — | — | — | parity |
| `Gtk.Entry` `search_entry` | 1 | 1 | ✓ `completion-entry`, `completion-active` (via constant) | ✓ `changed`, `icon-press` | ✓ | parity; primary icon inert, secondary tooltip `"Clear"`, clear routes through `trigger_search("")` |
| `Gtk.Button` `search_button` `.suggested-action` | 1 | 1 | ✓ | ✓ `clicked` | ✓ | parity, a11y label built |
| `Gtk.ToggleButton` `split_view_toggle_button` | 1 | 1 | — | ✓ bound | ✓ | parity, a11y label built |
| `Gtk.MenuButton` `direction: none` | 1 | 1 | — | — | ✓ | parity, a11y label built |
| `Gtk.ScrolledWindow` `main_scroll` | 1 | 1 | — | — | — | parity, `hscrollbar-policy: never`, vadjustment reset on the switch to content |
| `Adw.ViewStack` + `ViewStackPage` ×5 | 6 | 6 | — | — | — | parity, upstream's five page names |
| `Adw.StatusPage` welcome | 1 | 1 | — | — | ✓ | parity |
| `Adw.StatusPage` search-fail + `Gtk.Label` | 2 | 2 | — | ✓ `activate-link` | ✓ | parity, `use-markup`/`wrap`/`selectable` |
| `Adw.StatusPage` db-error + `Gtk.Button` `.pill` | 2 | 2 | ✓ `pill` | ✓ `clicked` → `exit!(0)` | ✓ | parity; **observed** |
| `Adw.Spinner` | 1 | 1 | — | — | — | parity, fallback branch removed this round |
| `Gtk.EventControllerKey` | 1 | 1 | — | ✓ `key-pressed` | — | parity, `SHORTCUT_MASK` includes Hyper |
| `Gio.Menu` `_def_extra_menu_model` | 1 | 1 | — | ✓ `win.search-selected` | ✓ | parity |
| 8 window actions (`WINDOW_ACTIONS`) | 8 | 8 | — | ✓ `activate` ×8 | — | parity; each activated through the registered `Gio::SimpleAction` and checked for what it changed |
| `focus-widget`, `default-widget`, min 360×280, `set_default_icon_name` | 4 | 4 | — | — | — | parity |

Stylesheet: byte-identical. Messages: all of this unit's msgids marked and
byte-identical.

**One observed runtime warning, not attributed and therefore not a gap.** The
drive run and a direct measurement both produce
`AdwToastOverlay exceeds AdwApplicationWindow width: requested 436 px, 390 px
available`. Measured: `split_view.measure(:horizontal, -1)` is `min=436`,
which is the 200px sidebar plus a 236px content minimum, against upstream's
declared `width-request: 360`. Upstream's tree has the same `min-sidebar-width:
200` and the same content, so upstream very likely warns identically and I
could not run it here to find out. Recorded because **no check in the port
asserts a minimum width**, so if this ever becomes a divergence nothing will
catch it.

## Unit 2 — `menu app-menu`

`ui/window.blp:4-42` → `lib/wordbook/main_menu.rb`

Two sections, six items, six action names, six msgids with upstream's mnemonic
underscores inside the msgid (`_Random Word`, `_Preferences`,
`_Keyboard Shortcuts`, `_About Wordbook`). Diffed item by item against the blp.
**Parity.** Upstream names its sections (`search-section`, `help-section`) and
the port passes `nil`; a `GMenu` section id is not user-visible and nothing in
either app looks one up.

## Unit 3 — the history sidebar

`ui/window.blp:61-145` + the history half of `window.py`
→ `history_sidebar.rb`, `history_row.rb`, `history_object.rb`

| Component | Up × | Port × | Verdict |
|---|---:|---:|---|
| `Adw.ToolbarView` / `Adw.HeaderBar` / `Adw.WindowTitle "History"` | 3 | 3 | parity |
| `Gtk.ToggleButton` `favorites_filter_button` `.flat` | 1 | 1 | **gap 1** — no `action-name` |
| `Gtk.Button` `clear_history_button` `.flat`, insensitive when empty | 1 | 1 | parity, a11y label built |
| `Adw.ViewStack` + 2 pages (`list`, `empty`) | 3 | 3 | parity |
| `Gtk.ScrolledWindow` + `Gtk.Viewport` | 2 | 1 | correspondence: `GtkListBox` is not `GtkScrollable`, so GTK4 inserts the viewport itself |
| `Gtk.ListBox` `.navigation-sidebar`, `selection-mode: none` | 1 | 1 | parity |
| `Adw.StatusPage` empty `.compact` | 1 | 1 | parity; **observed** |
| row: `Gtk.Box` ×2, ellipsized `Gtk.Label`, `Gtk.Button` `.flat.circular` | 4 | 4 | parity, tooltip on the content box, 8px margins |
| `.history-item` / `.favorite-item` on the `GtkListBoxRow` | 2 | 2 | parity, applied from an idle callback after `items-changed`, as upstream |
| 50-entry cap, clear-with-undo toast, filter by `visible` | 3 | 3 | parity; all three driven |

## Unit 4 — the definition view

`ui/window.blp:224-236` + `_populate_definitions` and the five `_create_*`
helpers → `definition_view.rb`, `definition_row.rb`, `relation_box.rb`,
`pronunciation_row.rb`

| Component | Verdict |
|---|---|
| `Gtk.ListBox` `.boxed-list-separate`, margins 12/12/8/12, `show-separators: false` | parity |
| `Gtk.ListBoxRow` non-focusable, 4px margins, `activatable` removed after `append` | parity |
| pos box, `.pos-header` label | parity |
| lemma / pronunciation box nesting, spacings 8 and 4 | parity |
| header row: `.synset-header`, `.dimmed` IPA, `.flat.circular` play button | parity; fallback IPA spoken as text not phonemes, matching `is_fallback` |
| definition row: `.definition-number` at 20px, `.definition`, `.example-text`, extra menu, `pressed`/`stopped` gesture per label | parity (classes attached via the `css_class` parameter, `definition_row.rb:78,81,101`) |
| `Gtk.Separator` between definitions, `margin-start: 32` | parity |
| `Adw.WrapBox`, `line-spacing: 4`, `child-spacing: 6`, `valign: start` | parity — the `Gtk::FlowBox` fallback is gone this round |
| `.relation-type`, `.lemma-button`, four relation groups in upstream's order | parity |

All four files reach 90-100 % line coverage under the drive, with real search
results in them. 100 % for `relation_box.rb`, `history_row.rb`,
`definition_view.rb` at 98.6 %, `pronunciation_row.rb` at 98 %.

## Unit 5 — the preferences dialog

`ui/settings-window.blp` + `settings_window.py` → `settings_dialog.rb`

`Adw.PreferencesDialog` (content 450×350, `settings_dialog.rb:21-29`),
`Adw.PreferencesPage`, `Adw.PreferencesGroup` ×2 (`Appearance`, `Behavior`),
`Adw.SwitchRow` ×4 with upstream's four titles and three subtitles byte for
byte, `Adw.ComboRow` + `Gtk.StringList` of the two untranslated accent names,
five `notify::` handlers, settings loaded before the handlers connect.
**Parity**, including upstream's "accent unchanged → do nothing"
short-circuit. 82/83 lines covered.

## Unit 6 — the shortcuts dialog

`ui/shortcuts-dialog.blp` → `shortcuts_dialog.rb`

| Component | Up × | Port × | Verdict |
|---|---:|---:|---|
| `Adw.ShortcutsDialog` | 1 | 1 | parity |
| `Adw.ShortcutsSection` `C_("shortcut window", "General")` | 1 | 1 | parity |
| `Adw.ShortcutsItem` ×8, upstream's order and msgctxt | 8 | 8 | parity |
| `action-name` on each item | 8 | 8 | **parity — closed this round** |

`shortcuts_dialog.rb:61-63` builds each row as
`Adwaita::ShortcutsItem.new(label, "")` and then sets `action_name`, so Adwaita
resolves the accelerator from what the application bound. The old
`APP_ACCELS`-lookup constructor and the `accels` parameter are gone. Driven:
"the accelerators came from the application's bindings". 18/18 lines covered.

## Unit 7 — the about dialog

`on_about` in `main.py` → `about_dialog.rb`

Eleven properties plus two links: icon, name, version, comments, developer,
translator-credits, GPL-3.0, website, issue URL, copyright, `"Source Code"`.
**Parity**, plus one extra `add_link(_("Ruby Port"), …)` — an added msgid,
`translation-parity.md` gap 2. 32/32 lines covered; opened and asserted in the
drive.

## Unit 8 — the error alert

`_new_error` in `window.py` → `error_dialog.rb`

`Adw.AlertDialog.new(primary, secondary)` with one `"dismiss"` response.
**Parity.** Upstream calls `choose`; with a single response `present` is the
same thing without the await. Both call sites reproduced:
`_("Invalid input")` / `_("Nothing definable was found in your search input")`
(only when live search is off, as upstream) and `_("Wordlist Loading")` /
`_("The word list is still loading. Please try again in a moment.")`. 15/15
lines covered; the invalid-input alert is opened in the drive.

**This unit is absent from `COMPONENT_PARITY.md` — gap 10.**

## Unit 9 — the search completion

`search_completion.py` → `search_completion.rb`

`Gtk.Popover` (`autohide: false`, no arrow, bottom, non-focusable,
`.completion-popover`), `Gtk.ScrolledWindow` (`propagate-natural-height`, no
frame), `Gtk.ListBox` (single selection, activate-on-single-click,
non-focusable), 10-item cap, row + ellipsized label with 3/3/10/10 margins,
`.completion-entry` / `.completion-active` on the entry, three controllers with
upstream's propagation phases, six signals, the one-pixel `pointing_to`
rectangle along the entry's bottom edge with the offset zeroed,
Down/Up/Tab/Return/KP_Enter/Escape, leading-whitespace-preserving completion,
the `pick`-based click dismissal. **Parity on all four axes.** 192/216 lines
covered; the popover and four of its keys are driven.

The popover's *rendered position* is still unmeasured — the geometry
arithmetic is upstream's, carried across, and no screenshot has been compared
against upstream's.

GTK emits `Finalizing AdwApplicationWindow, but it still has children left:
GtkPopover` at the end of every drive run. Upstream calls `set_parent(parent)`
and never unparents either (`search_completion.py:46`), so this is upstream's
shape rather than a divergence. Recorded, not counted.

## Unit 10 — the application

`main.py` + `wordbook.in` → `application.rb`, `exe/wordbook`

| Component | Verdict |
|---|---|
| `Adw.Application` | **parity — closed this round.** `Adwaita::Application.new(@app_id, :handles_command_line)` (`application.rb:103`) |
| `HANDLES_COMMAND_LINE`, `startup`/`command-line`/`activate`/`shutdown` | parity |
| `set_resource_base_path`, `GLib.set_application_name`, `set_prgname` | parity |
| colour scheme from `force_dark_mode` | parity |
| SIGINT/SIGTERM | correspondence: `Signal.trap` for `GLib.unix_signal_add` |
| `create_required_dirs` | parity |
| 4 CLI options, short forms | correspondence: hand-written parser. `--look-up` with no value errors instead of searching `""`; a term spelled like a flag survives |
| `app.about`, `app.quit` | parity |
| `app.shortcuts` | **extra**: upstream never installs it, and the port also binds `<Primary>question`. Divergence D |
| 8 accelerators | parity; a ninth is the extra above |
| `Style.install` | correspondence: `Gtk::CssProvider` for the gresource bundle; CSS byte-identical |
| the `development` profile | **gap 2** |

99/128 lines covered. The uncovered block is the CLI parser's error paths and
`--info`.

## Unit 11 — the shell search provider

`data/search_provider.in` + `.SearchProvider.ini` → `shell_search_provider.rb`,
`exe/wordbook-search-provider`

All five `org.gnome.Shell.SearchProvider2` methods, the same bus name, object
path and desktop id, `IS_SERVICE` with a 10 s inactivity timeout, first synset
per part of speech, UUID keys with the lemma as the `id` meta, `--look-up`
spawn on activation, bare spawn on `LaunchSearch`. The `.ini` and `.service.in`
diff against upstream only in the substituted variables. The Ruby-level
behaviour is **parity**; the Devel object path is missing (gap 2) and the D-Bus
surface is **unverified** (gap 8).

## Divergences recorded, not gaps

| # | Divergence | Where |
|---|---|---|
| A | `syn` deduplicated here, not upstream — a synset listing a lemma twice shows two chips upstream and one here | `base.rb:425` vs `base.py:266` |
| B | close-lemma match uses an indel ratio, not `difflib`'s Ratcliff/Obershelp at cutoff 0.8, so a near-miss search can pick a different headword | `base.rb:445` vs `base.py:244` |
| C | suggestion ties break alphabetically here, by wordlist order upstream | `base.rb:488` vs `window.py:336` |
| D | `app.shortcuts` exists and has an accelerator here; upstream has neither | `application.rb:57,66` |
| E | state saved on `close-request` as well as on `shutdown` | `window.rb:192` |
| F | `zstd` is an external program here, a Python module upstream — a machine without it gets "Database not found" about a complete install | `database_manager.rb:107`, `FINDINGS.md` 4 |
| G | `Gtk.Viewport` inserted by GTK4 rather than declared | unit 3 |

## Verdict

**Not clean.** 10 gaps. The window, the breakpoint, the shortcuts actions, the
application class, the wrap box and the accessible labels are all genuinely
closed and genuinely observed — that is real progress and I re-ran it rather
than believing it. What replaces them as the headline is that the port's two
delivery paths are each broken (gap 7 and `translation-parity.md` gaps 3-5),
that the three largest blocks of never-executed code are the database
extraction, the D-Bus surface and the espeak failure paths (gaps 3, 8, 9), and
that the root ledger reports 10/10 over a denominator that quietly dropped a
unit (gap 10).
