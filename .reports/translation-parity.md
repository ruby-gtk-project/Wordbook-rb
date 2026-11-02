# Translation parity — Wordbook-rb

| | |
|---|---|
| Upstream | `main` @ `4b43165` |
| Port | `ruby` @ `a73a55a` |
| Domain | `wordbook` (from `po/meson.build`) → port: **none** |
| Messages | 63 → **0** |
| Occurrences | 77 → **0** |
| Ported | **0** |
| Gaps | **63** |
| Languages | 15 → **0** |
| Translated strings | **780 → 0** |
| Unresolved markers | 0 → 0 |

**The port produces no message catalogue at all.** Every user-visible string in
`lib/` is a bare Ruby literal. There is no `gettext` gem in the `Gemfile` or
the gemspec, no `po/`, no `POTFILES`, no `LINGUAS`, no `.pot`, no
`bindtextdomain` call and no `_()`, `n_()`, `p_()` or `s_()` anywhere in the
tree:

```
$ msgid-census.sh <port> | wc -l
0
```

Fifteen catalogues and 780 translated strings exist today, upstream, in the
same repository. Shipping without them is a regression this port introduced,
not a feature it has not reached.

## Reconciliation of the upstream number

| | |
|---|---:|
| distinct `(msgctxt, msgid)` keys in the census | 63 |
| call sites | 77 |
| messages reused (>1 site) | 9 |
| messages with a context | 9 (all `msgctxt "shortcut window"`) |
| plural forms | 0 |
| non-empty msgids in `po/wordbook.pot` | 52 |
| `.po` files | 15 |
| msgids per `.po` | 52 + the header, in all 15 |
| translated strings | 15 × 52 = **780**, untranslated 0, fuzzy 0 |

`ls po/*.po` and `po/LINGUAS` agree exactly (de, fa, fr, hi, hr, hu, it, kk,
nl, oc, ru, tr, vi, zh_CN, zh_TW). Every catalogue is 100% complete with no
fuzzies — this is an unusually well-maintained `po/` and the port discards all
of it.

**Eleven source msgids are in no catalogue at all**, which per
`translation-parity` Step 1 is the third case and an upstream bug found today:

```
Dark Mode              Dark mode             dictionary;
Double click to search Favorites             Features:
Fully offline          Light Mode            Pronunciations
Wordbook is an offline English-English dictionary application powered by WordNet and eSpeak.
```

All of them live in `data/dev.mufeed.Wordbook.metainfo.xml.in.in` and
`data/dev.mufeed.Wordbook.desktop.in.in`, and **`po/POTFILES` lists neither
file** — it names only the three `.blp`s and `main.py`, `window.py`,
`settings_window.py`. `xgettext` has therefore never read them and no
translator has ever been offered those strings, in any of the 15 languages.
Carry them into the port anyway and list the port's files in its own
`POTFILES`: the port then offers a translation upstream cannot. Report the bug
upstream.

`po/wordbook.pot` is dated `2026-04-11` against an upstream HEAD of
`2026-10-26`, so it is a lead and not ground truth; it reconciles against the
source census (52 = 63 − 11) and against all 15 `.po` files, so it is trusted
here.

## The ledger

63 rows, every one a gap. `Uses` is upstream's call-site count — the porting
order, most-reused first.

| # | ctxt | msgid | Uses | Upstream site | Port site | State |
|---:|---|---|---:|---|---|---|
| 1 | — | `Wordbook` | 6 | `main.py:37,98,152`, `window.blp:216`, `desktop.in.in:3`, metainfo | `window.rb:793,914`, `about_dialog.rb:14` | **gap** |
| 2 | — | `Look up definitions for words` | 3 | `main.py:154`, `desktop.in.in:5`, metainfo | `about_dialog.rb:15` | **gap** |
| 3 | — | `Clear History` | 2 | `window.blp:92,96` | `history_sidebar.rb:177` (tooltip only; the a11y label is not built) | **gap** |
| 4 | — | `History` | 2 | `window.blp:71`, metainfo | `history_sidebar.rb:144` | **gap** |
| 5 | — | `Main Menu` | 2 | `window.blp:194,197` | `window.rb:891` (tooltip only) | **gap** |
| 6 | — | `Search` | 2 | `window.blp:167,170` | `window.rb:874` (tooltip only) | **gap** |
| 7 | — | `Search Selected Text` | 2 | `window.blp:14`, `window.py:178` | `main_menu.rb:15`, `window.rb:965` | **gap** |
| 8 | — | `Show Favorites Only` | 2 | `window.blp:77,81` | `history_sidebar.rb:169` (tooltip only) | **gap** |
| 9 | — | `Show History` | 2 | `window.blp:182,185` | `window.rb:882` (tooltip only) | **gap** |
| 10 | — | `Appearance` | 1 | `settings-window.blp:10` | `settings_dialog.rb:75` | **gap** |
| 11 | — | `Auto Paste on Launch` | 1 | `settings-window.blp:31` | `settings_dialog.rb:107` | **gap** |
| 12 | — | `Automatically paste and search clipboard content on launch` | 1 | `settings-window.blp:32` | `settings_dialog.rb:108` | **gap** |
| 13 | — | `Behavior` | 1 | `settings-window.blp:18` | `settings_dialog.rb:81` | **gap** |
| 14 | — | `Clear` | 1 | `window.blp:161` | `window.rb:867` | **gap** |
| 15 | — | `Copyright © 2016-2026 Mufeed Ali` | 1 | `main.py:161` | `about_dialog.rb:17` | **gap** |
| 16 | — | `Database not found` | 1 | `window.blp:260` | `window.rb:938` | **gap** |
| 17 | — | `Dismiss` | 1 | `window.py:872` | `error_dialog.rb:30` | **gap** |
| 18 | — | `Double Click Search` | 1 | `settings-window.blp:26` | `settings_dialog.rb:100` | **gap** |
| 19 | — | `Exit` | 1 | `window.blp:264` | `window.rb:944` | **gap** |
| 20 | — | `Force Dark Mode` | 1 | `settings-window.blp:13` | `settings_dialog.rb:87` | **gap** |
| 21 | — | `History cleared` | 1 | `window.py:513` | `history_sidebar.rb:109` | **gap** |
| 22 | — | `Installation is incomplete. Please reinstall Wordbook.` | 1 | `window.blp:261` | `window.rb:939` | **gap** |
| 23 | — | `Invalid input` | 1 | `window.py:898` | `window.rb:299` | **gap** |
| 24 | — | `Listen to Pronunciation` | 1 | `window.py:674` | `pronunciation_row.rb:88` | **gap** |
| 25 | — | `Live Search` | 1 | `settings-window.blp:21` | `settings_dialog.rb:93` | **gap** |
| 26 | — | `Look up definitions of any English term` | 1 | `window.blp:217` | `window.rb:915` | **gap** |
| 27 | — | `No definition found` | 1 | `window.blp:245` | `window.rb:923` | **gap** |
| 28 | — | `No recent searches or favorites` | 1 | `window.blp:132` | `history_sidebar.rb:186` | **gap** |
| 29 | — | `Nothing definable was found in your search input` | 1 | `window.py:899` | `window.rb:299` | **gap** |
| 30 | — | `Paste & Search` | 1 | `window.blp:9` | `main_menu.rb:14` | **gap** |
| 31 | — | `Pronunciations Accent` | 1 | `settings-window.blp:36` | `settings_dialog.rb:114` | **gap** |
| 32 | — | `Search any word by double clicking on it` | 1 | `settings-window.blp:27` | `settings_dialog.rb:101` | **gap** |
| 33 | — | `Show definition as the terms are typed in` | 1 | `settings-window.blp:22` | `settings_dialog.rb:94` | **gap** |
| 34 | — | `Source Code` | 1 | `main.py:159` | `about_dialog.rb:41` | **gap** |
| 35 | — | `The word list is still loading. Please try again in a moment.` | 1 | `window.py:279` | `window.rb:626` | **gap** |
| 36 | — | `Toggle Favorite` | 1 | `window.py:815` | `history_row.rb:98` | **gap** |
| 37 | — | `Undo` | 1 | `window.py:514` | `window.rb:759` | **gap** |
| 38 | — | `Wordlist Loading` | 1 | `window.py:278` | `window.rb:626` | **gap** |
| 39 | — | `_About Wordbook` | 1 | `window.blp:38` | `main_menu.rb:22` | **gap** |
| 40 | — | `_Keyboard Shortcuts` | 1 | `window.blp:33` | `main_menu.rb:21` | **gap** |
| 41 | — | `_Preferences` | 1 | `window.blp:28` | `main_menu.rb:20` | **gap** |
| 42 | — | `_Random Word` | 1 | `window.blp:19` | `main_menu.rb:16` | **gap** |
| 43 | — | `translator-credits` | 1 | `main.py:156` | `about_dialog.rb:36` (a bare literal, so it renders the word "translator-credits" in the About dialog's credits tab rather than the translators' names) | **gap** |
| 44 | shortcut window | `General` | 1 | `shortcuts-dialog.blp:6` | `shortcuts_dialog.rb:17` | **gap** |
| 45 | shortcut window | `Show Shortcuts` | 1 | `shortcuts-dialog.blp:9` | `shortcuts_dialog.rb:18` | **gap** |
| 46 | shortcut window | `Preferences` | 1 | `shortcuts-dialog.blp:14` | `shortcuts_dialog.rb:19` | **gap** |
| 47 | shortcut window | `Paste and Search` | 1 | `shortcuts-dialog.blp:19` | `shortcuts_dialog.rb:20` | **gap** |
| 48 | shortcut window | `Random Word` | 1 | `shortcuts-dialog.blp:24` | `shortcuts_dialog.rb:21` | **gap** |
| 49 | shortcut window | `Search Selected Text` | 1 | `shortcuts-dialog.blp:29` | `shortcuts_dialog.rb:22` | **gap** |
| 50 | shortcut window | `Toggle Sidebar` | 1 | `shortcuts-dialog.blp:34` | `shortcuts_dialog.rb:23` | **gap** |
| 51 | shortcut window | `Show Menu` | 1 | `shortcuts-dialog.blp:39` | `shortcuts_dialog.rb:24` | **gap** |
| 52 | shortcut window | `Quit` | 1 | `shortcuts-dialog.blp:44` | `shortcuts_dialog.rb:25` | **gap** |
| 53 | — | `dictionary;` | 1 | `desktop.in.in:11` | — | **gap**: no desktop file in the port. Never extracted upstream either |
| 54 | — | `Dark Mode` | 1 | metainfo | — | **gap**: no metainfo in the port. Never extracted upstream |
| 55 | — | `Dark mode` | 1 | metainfo | — | **gap**, as above |
| 56 | — | `Double click to search` | 1 | metainfo | — | **gap**, as above |
| 57 | — | `Favorites` | 1 | metainfo | — | **gap**, as above |
| 58 | — | `Features:` | 1 | metainfo | — | **gap**, as above |
| 59 | — | `Fully offline` | 1 | metainfo | — | **gap**, as above |
| 60 | — | `Light Mode` | 1 | metainfo | — | **gap**, as above |
| 61 | — | `Pronunciations` | 1 | metainfo | — | **gap**, as above |
| 62 | — | `Random Word` | 1 | metainfo | — | **gap**, as above |
| 63 | — | `Wordbook is an offline English-English dictionary application powered by WordNet and eSpeak.` | 1 | metainfo | — | **gap**, as above |

Rows 1–52 are the ones the 780 translations are keyed on. Rows 53–63 are owed
anyway.

## The `msgctxt` trap

Rows 44–52 carry `msgctxt "shortcut window"` — blueprint's `C_("shortcut
window", "Preferences")`. `Preferences` **with** that context and
`_Preferences` **without** it are two different keys in the catalogue, and all
15 languages translate both. A port that marks the shortcuts dialog's labels
with a plain `_()` produces nine keys nobody has translated *and* leaves nine
upstream keys unproduced: eighteen wrong rows from one omitted argument. The
port must use `p_("shortcut window", "Preferences")`.

## Extra keys the port would introduce

Strings the port shows that upstream does not have. Each one is a key no
language has ever been offered, so each needs either removing or proposing
upstream:

| Port string | Site | Why it exists |
|---|---|---|
| `Preferences` (dialog title) | `settings_dialog.rb:25` | upstream's `Adw.PreferencesDialog` has no title set |
| `Keyboard Shortcuts` (dialog title) | `shortcuts_dialog.rb:31` | upstream's `Adw.ShortcutsDialog` has no title set |
| `Ruby Port` (About link label) | `about_dialog.rb:42` | the port's own repository link |
| `Did you mean: …?` | `window.rb:364` | interpolated — see below. Upstream's is also unmarked |

## Interpolation

`window.rb:364` builds

```ruby
"Did you mean: #{links.join(", ")}?"
```

`#{}` runs before any marker could see it, so this is not a translatable string
in any form — the key would differ on every call. Upstream has the same bug at
`window.py:371`, which is *why* that sentence appears in none of the 15
catalogues and is still English in every language. Inheriting the bug is not
parity work; marking it is. The port should build
`format(_("Did you mean: %s?"), links.join(", "))` and offer the string
upstream.

## What has to happen

1. Add `gettext` to the gemspec as a runtime dependency and call
   `bindtextdomain("wordbook")` at startup; the domain is `wordbook`, confirmed
   from `po/meson.build`.
2. Copy `po/` across unchanged — all 15 `.po` files, `LINGUAS` and
   `wordbook.pot` — and write a `POTFILES` naming the port's own files.
3. Mark all 52 extracted msgids byte-identically, `p_("shortcut window", …)`
   for rows 44–52. Mnemonic underscores stay (`_Preferences`, not
   `Preferences`).
4. Write `data/` so rows 53–63 have somewhere to live: the desktop entry, the
   metainfo and the icons.
5. Build `.mo` files per language and install them where `bindtextdomain` looks.
6. Never reword an upstream msgid to match a port literal. Upstream's bytes are
   what 780 translations are keyed on; the port moves to them.
