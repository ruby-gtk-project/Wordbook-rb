# Drive verification — Wordbook-rb

| | |
|---|---|
| Port | `ruby` @ `0a35cd6` |
| Harness | `test/drive_wordbook.rb` + `test/gtk_driver.rb` |
| Fixture | `test/wn_fixture.rb` — a small WordNet database in `wn`'s schema |
| Command | `nix develop --command xvfb-run -a ruby test/drive_wordbook.rb` |
| Result | **198 of 198 checks passed over 78 steps — `DRIVE OK`** |
| Spec suite | `118 examples, 0 failures` |
| Screenshots | 19 PNGs in `tmp/shots` |
| Re-run for this audit | **yes — both commands, from this checkout** |

Both numbers in the runtime gate were reproduced rather than quoted. The dev
shell's banner names the commands; `Gtk::Version` is the constant, and
`require "gtk4"` outside `xvfb-run` still raises `Gtk::InitError`, which is why
the banner exists.

## What is driven

Every file in `lib/` is entered: the application with its actions and
accelerators, the window and all five stack pages, the definition view,
definition rows, pronunciation rows and relation chips with real search
results, the history sidebar with rows, favourites, the filter, the
clear-with-undo toast and the empty state, the completion popover and four of
its keys, the quick-search key controller, all four dialogs, the main menu, the
`Adw.Breakpoint` collapsing at 420 px and releasing at 900 px, the stylesheet,
the settings round trip through the JSON file, espeak-ng, the database manager
and the search provider.

## Coverage, measured rather than asserted

Line coverage over `lib/` under the drive run alone, with Ruby's `Coverage`
(`lines: true`):

**1833 / 2038 = 89.9 %, across 26 files, every one of which is entered.**

So the gate's "26 components" are genuinely exercised. Three files sit far
below the rest, and in each the uncovered block is one whole behaviour:

| File | Covered | The block no check enters |
|---|---:|---|
| `database_manager.rb` | 37/68 | the archive path — `extract_database`, `decompress`, the `zstd` call and its two failure raises, `cleanup_old_versions`, `old_version_dirs`, the success branch of `find_compressed_db`. Every line a real install runs |
| `shell_search_provider.rb` | 57/90 | the D-Bus surface — `run`, `register`, `handle_method_call`, the `Process.spawn`, and the `GLib::Variant` builders `string_array` / `metas_variant` / `quote` |
| `espeak.rb` | 46/70 | the `TERM` timeout kill, the non-zero exit, `Errno::ENOENT`, the LRU eviction, the whole `--version` path |

The rest: `application.rb` 77 %, `search_completion.rb` 89 %, `settings.rb`
90 %, `base.rb` 93 %, `window.rb` 95 %, and ten files at 98-100 %.

## What this run still does not settle

- **the archive is never unpacked.** The driver searches the fixture database,
  written straight into place, so `component-parity.md` gap 3 hides behind a
  green run rather than being exposed by it;
- **the overview never calls the search provider.** The six green checks in
  that step call plain Ruby methods; the marshalling GNOME Shell would exercise
  is at zero coverage (`component-parity.md`, gap 8);
- **the packaged app is not what is driven.** `nix build` produces an artifact
  whose bundle has no `sqlite3`, so it raises `LoadError` on the first search —
  proved directly, `component-parity.md` gap 7. Every green run here is on the
  dev shell's load path;
- **the catalogues are not what a clone has.** `/locale/` is gitignored; the
  drive reads an untracked directory, and a `git archive` of HEAD runs English
  in all fifteen languages (`translation-parity.md`, gap 3);
- **no minimum-width assertion exists.** The run emits
  `AdwToastOverlay exceeds AdwApplicationWindow width: requested 436 px,
  390 px available`; measured, `split_view` has a 436 px minimum against
  upstream's declared `width-request: 360`. Upstream's tree has the same
  200 px sidebar so this is probably not a divergence, and nothing would catch
  it if it became one;
- **the screenshots have not been put beside upstream's** and compared;
- **keyboard accelerators** are verified through the accelerator table and what
  the shortcuts dialog resolves from it, not by synthesising key events: GTK4
  exposes no way to inject one. The quick-search handler is driven by emitting
  `key-pressed` on the window's own `Gtk::EventControllerKey`.

## Two defects earlier runs of this harness found

Kept because they are why the harness exists.

**The clipboard handlers rescued a class the bindings never raise.** Upstream
catches `GLib.Error`; these bindings raise `Gio::IOError::NotFound`, which
descends from `Gio::Error` and not `GLib::Error`. An empty primary selection
raised out of a signal handler and ended the process. `FINDINGS.md` 11.

**`Gtk::Widget#activate_action` activates nothing in these bindings.** It
returns the widget and has no effect. An earlier driver checked seven window
actions with it and asserted only that it did not raise, so seven green checks
covered nothing. Actions are now activated through the `Gio::SimpleAction` the
window registered and each is checked for what it changed. `FINDINGS.md` 12.
