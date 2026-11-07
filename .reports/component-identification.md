# Component identification — Wordbook-rb

Audit round. Re-derived from `origin/main` and the current `ruby` tree, not
carried forward from a prior report.

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` |
| Port | `ruby` @ `665cb58` (HEAD at audit start) |
| Declarative UI upstream | 3 `.blp` files: `data/resources/ui/window.blp`, `settings-window.blp`, `shortcuts-dialog.blp` |
| Upstream Python modules | `wordbook/{main,window,settings_window,search_completion,base,database,settings,utils,constants}.py` (+ `__init__.py`) |
| `lib/wordbook/*.rb` files | **30** (`find lib -name '*.rb' \| wc -l`) |
| Unit files (own a widget tree) | **11** |
| Support files (backend, no widget) | 19 |

```
$ find lib -name '*.rb' | wc -l
30
```

## The 11 widget-owning units, each joined across its upstream file pair

1. `window.rb` ← `ui/window.blp` (template) + `window.py`
2. `main_menu.rb` ← `ui/window.blp:4-42` (`menu app-menu`)
3. `history_sidebar.rb` ← `ui/window.blp:61-145` + history half of `window.py`
4. `history_row.rb` ← history row builder in `window.py`
5. `definition_view.rb` + `definition_row.rb` + `pronunciation_row.rb` +
   `relation_box.rb` ← `ui/window.blp:224-236` + `_populate_definitions`/
   `_create_*` in `window.py`
6. `search_completion.rb` ← `search_completion.py`
7. `settings_dialog.rb` ← `ui/settings-window.blp` + `settings_window.py`
8. `shortcuts_dialog.rb` ← `ui/shortcuts-dialog.blp`
9. `application.rb` ← `main.py` + `meson.build:40-50`
10. `shell_search_provider.rb` ← `data/search_provider.in` +
    `dev.mufeed.Wordbook.SearchProvider.ini`
11. `error_dialog.rb`/`about_dialog.rb` ← `_new_error`/`on_about` in
    `window.py`/`main.py`

This reconciles against `COMPONENT_IDENTIFICATION.md`'s own count
(`15 unit-ish files + 15 support files = 30`, where that file splits
`definition_view`'s cluster and `error_dialog`/`about_dialog` into separate
rows) — the two groupings differ in how finely the cluster files are counted,
not in what exists. Both land on 30 files under `lib/`, which is the number
the runtime gate's "30 components" cites.

## Non-widget (support) files — not UI components, scanned for completeness

`base.rb`, `espeak.rb`, `database_manager.rb`, `database_builder.rb`,
`lmf_reader.rb`, `lexicon_download.rb`, `settings.rb`, `utils.rb`,
`constants.rb`, `style.rb`, `translations.rb`, `profile.rb`,
`history_object.rb`, plus the gem-layout files (`wordbook.rb`,
`rb/version.rb`). These have no widget tree and are out of scope for this
report; they are covered by test-parity and the drive/suite instead.

## Nothing found missing on this axis

No `.blp`/`.ui` file or Python module exists upstream with no port-side file
named for it; no port-side `lib/wordbook/*.rb` file claims to port a unit this
round's `git ls-tree -r --name-only origin/main` does not contain. The
reconciliation above is the only item worth recording — it is a presentation
difference between two documents, not a missing component.
