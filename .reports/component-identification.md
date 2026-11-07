# Component identification — Wordbook-rb

Audit round. Re-derived from `origin/main` and the current `ruby` tree.

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` (unchanged since the last two audit rounds) |
| Port | `ruby` @ `d3c3f60` (HEAD at audit start) |
| Declarative UI upstream | 3 `.blp` files: `data/resources/ui/window.blp`, `settings-window.blp`, `shortcuts-dialog.blp` |
| Upstream Python modules | `wordbook/{main,window,settings_window,search_completion,base,database,settings,utils,constants}.py` (+ `__init__.py`) |
| `lib/wordbook/*.rb` files | **30** (`find lib -name '*.rb' | wc -l`, re-run this round, unchanged) |
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

This still reconciles against `COMPONENT_IDENTIFICATION.md`'s own count
(15 unit-ish files + 15 support files = 30) — a counting-granularity
difference, not a missing-file difference. No new upstream file appeared on
`origin/main` this round (its HEAD is still `4b43165`, confirmed by
`git rev-parse origin/main`), so this report is a re-check, not a re-derive
from a moved target.

## Nothing found missing on this axis

No `.blp`/`.ui` file or Python module exists upstream with no port-side file
named for it; no port-side `lib/wordbook/*.rb` file claims to port a unit
`git ls-tree -r --name-only origin/main` does not contain. Re-confirmed this
round with the same commands as the prior audit; the finding is unchanged:
**0 missing files on this axis.**

## What this axis does not cover

Component *identification* only asks "does a port-side file exist for every
upstream file". It says nothing about whether each file's widgets, actions,
strings or behaviour actually match — that is `component-parity.md`, and it
is where this round's real findings live (translation-parity's 12 extra
msgids; the search-provider driver's flakiness documented in
`test-parity.md` and `accountability-ensurance.md`). A reader who stops here
would wrongly conclude the port is fully verified; it is not.
