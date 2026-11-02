# Porting Wordbook to Ruby

Upstream is Wordbook: a GTK4/Libadwaita offline English dictionary in Python
(PyGObject), with its UI in three Blueprint files, its lookups in a bundled
Open English WordNet SQLite database read through the `wn` package, and its
pronunciations from `espeak-ng`. This branch is the port.

| | |
|---|---|
| Upstream | `origin/main` (Python + Blueprint + meson) |
| Port | `ruby` (Ruby 3.4, `gtk4`/`adwaita` gems, gem layout) |
| Upstream as spec | read with `git show origin/main:<path>`; never merged |

## The mapping

One upstream source file becomes one `lib/wordbook/*.rb`. Upstream splits most
units across a `.blp` and a `.py`; the port folds both halves into the one file
that owns the widget.

| Upstream | Port |
|---|---|
| `wordbook/main.py` | `lib/wordbook/application.rb` |
| `data/resources/ui/window.blp` + `wordbook/window.py` | `lib/wordbook/window.rb`, and the extracted `history_sidebar.rb`, `history_row.rb`, `history_object.rb`, `definition_view.rb`, `definition_row.rb`, `pronunciation_row.rb`, `relation_box.rb`, `error_dialog.rb`, `main_menu.rb` |
| `data/resources/ui/settings-window.blp` + `wordbook/settings_window.py` | `lib/wordbook/settings_dialog.rb` |
| `data/resources/ui/shortcuts-dialog.blp` | `lib/wordbook/shortcuts_dialog.rb` |
| `on_about` in `wordbook/main.py` | `lib/wordbook/about_dialog.rb` |
| `wordbook/search_completion.py` | `lib/wordbook/search_completion.rb` |
| `wordbook/base.py` | `lib/wordbook/base.rb` (lookups, scorers) + `lib/wordbook/espeak.rb` (the subprocess half) |
| `wordbook/settings.py` | `lib/wordbook/settings.rb` |
| `wordbook/database.py` | `lib/wordbook/database_manager.rb` |
| `wordbook/utils.py` | `lib/wordbook/utils.rb` |
| `wordbook/constants.py` | `lib/wordbook/constants.rb` |
| `data/resources/style.css` | `lib/wordbook/style.rb` |
| `data/search_provider.in` + `.SearchProvider.ini` | `lib/wordbook/shell_search_provider.rb`, `exe/wordbook-search-provider`, `data/dev.mufeed.Wordbook.SearchProvider.ini`, `.service.in` |
| `gettext` imports + blueprint `_()`/`C_()` | `lib/wordbook/translations.rb` |
| `po/` | `po/` — carried across unchanged, with the port's own `POTFILES` |
| `data/*.desktop.in.in`, `*.metainfo.xml.in.in`, `data/icons/*` | `data/` — same strings, app id substituted |
| `meson.build`, `data/meson.build`, `po/meson.build` | `flake.nix` install phase + `rake install:data` + `rake gettext:mo:update` |

Not ported: `scripts/generate-wn-db.py` (see `FINDINGS.md`, defect 7),
`data/*.gschema.xml.in` (upstream's schema is empty; all state is the JSON
config file), the flatpak manifest, `Wordbook.doap`.

## House style

The `ruby-gtk` skill in `.claude/skills/` is the contract. In short:

- every file opens with `# frozen_string_literal: true`, then its `require`s,
  then `require_relative` for its siblings;
- every class carries a comment naming the upstream file it was ported from
  and anything worth knowing about how it differs;
- widgets are memoized accessors (`def entry = @entry ||= …`) with their
  styling in a `.tap` block; `build` holds only structure and signals, nested
  so it reads as the widget tree;
- no `return`, no modifier `if`, no conditional assignment — `.then`, `.tap`
  and full `if`/`else`. The custom cops in `cops/` enforce it.

## What a round looks like

1. read the upstream file with `git show origin/main:<path>` before writing the
   Ruby. The upstream source is the spec, and skipping it is how a port ends up
   with the right file names and the wrong behaviour;
2. write the unit, with the comment naming its upstream;
3. mark every user-visible string with `_()`, `n_()` or
   `p_("shortcut window", …)`, using upstream's msgid byte for byte — the 780
   donated translations are keyed on those bytes;
4. add the specs for anything expressible without a widget;
5. run `ruby -c`, `bundle exec rubocop`, and the spec suite;
6. update `COMPONENT_PARITY.md`, `TRANSLATION_PARITY.md`, `TEST_PARITY.md` and
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
directory to search anything at all; it does not build one.

## Where the ledgers are

| File | Holds |
|---|---|
| `FINDINGS.md` | ruby-gnome binding defects and environment limits — why a gap is hard |
| `COMPONENT_PARITY.md` | every upstream unit against its port, and the behaviour divergences |
| `TRANSLATION_PARITY.md` | the 63-message ledger, the 15 catalogues, the keys the port adds |
| `TEST_PARITY.md` | upstream has no suite; what the port owes itself and what runs |
| `.reports/` | the per-skill audits a round was opened with. Point-in-time; the four files above are what is kept current |
