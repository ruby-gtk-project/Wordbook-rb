# Translation parity — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` |
| Domain | `wordbook` (from upstream's `po/meson.build`) → port: **`wordbook`** |
| Upstream messages | 63 distinct `(msgctxt, msgid)` keys over 77 call sites |
| Extracted into `po/wordbook.pot` | 52 |
| Marked in the port | **52 / 52**, byte-identically |
| Languages | 15 → **15** |
| Translated strings | 780 → **780** |
| Keys the port adds | 2, recorded below |
| Unresolved markers | 0 |

The previous round produced zero translatable messages: no gettext gem, no
`po/`, no `bindtextdomain`, and every user-visible string a bare Ruby literal.
Fifteen complete catalogues and 780 translated strings existed in the same
repository and the port discarded all of them. That is what this round closed.

## How it is wired

| | |
|---|---|
| gem | `gettext ~> 3.5`, a runtime dependency in `wordbook-rb.gemspec` and in `nix/Gemfile` |
| module | `lib/wordbook/translations.rb` — `include GetText` and `bindtextdomain("wordbook", path: LOCALE_DIR)` once; every class with strings includes it, and the lookup is found through the ancestor chain |
| locale dir | `WORDBOOK_LOCALE_DIR`, else `locale/` beside `lib/`, else `<XDG data dir>/locale` |
| catalogues | `po/` is upstream's tree, carried across unchanged: 15 `.po`, `LINGUAS`, `wordbook.pot` |
| compiled | `rake gettext:mo:update` → `locale/<lang>/LC_MESSAGES/wordbook.mo`. Build output, gitignored, packaged by the gemspec and built into `$out/share/Wordbook/locale` by `flake.nix` |
| GLib side | `Translations.bind_glib_domain` binds the same domain through libintl, for the desktop entry and the metainfo |

Verified, not asserted: with `LANGUAGE=de`, `_("Clear History")` returns
"Verlauf löschen", `_("_Preferences")` returns "_Einstellungen" and
`p_("shortcut window", "Preferences")` returns "Einstellungen" — the two
`Preferences` keys resolving separately is the whole point of the context.

## The ledger

Rows 1–52 are upstream's extracted messages, all marked. The nine
`msgctxt "shortcut window"` keys are marked with
`p_("shortcut window", …)`, which is what blueprint's `C_()` produces.

| # | ctxt | msgid | Port site | State |
|---:|---|---|---|---|
| 1 | — | `Wordbook` | `window.rb` (title, welcome page), `about_dialog.rb`, `application.rb` | ported |
| 2 | — | `Look up definitions for words` | `about_dialog.rb` | ported |
| 3 | — | `Clear History` | `history_sidebar.rb` (tooltip **and** accessible label) | ported |
| 4 | — | `History` | `history_sidebar.rb` | ported |
| 5 | — | `Main Menu` | `window.rb` (tooltip **and** accessible label) | ported |
| 6 | — | `Search` | `window.rb` (tooltip **and** accessible label) | ported |
| 7 | — | `Search Selected Text` | `main_menu.rb`, `window.rb` | ported |
| 8 | — | `Show Favorites Only` | `history_sidebar.rb` (tooltip **and** accessible label) | ported |
| 9 | — | `Show History` | `window.rb` (tooltip **and** accessible label) | ported |
| 10–13 | — | `Appearance`, `Behavior`, `Live Search`, `Show definition as the terms are typed in` | `settings_dialog.rb` | ported |
| 14–17 | — | `Double Click Search`, `Search any word by double clicking on it`, `Auto Paste on Launch`, `Automatically paste and search clipboard content on launch` | `settings_dialog.rb` | ported |
| 18–20 | — | `Force Dark Mode`, `Pronunciations Accent`, `Clear` | `settings_dialog.rb`, `window.rb` | ported |
| 21–24 | — | `Database not found`, `Installation is incomplete. Please reinstall Wordbook.`, `Exit`, `No definition found` | `window.rb` | ported |
| 25–28 | — | `Invalid input`, `Nothing definable was found in your search input`, `Wordlist Loading`, `The word list is still loading. Please try again in a moment.` | `window.rb` | ported |
| 29–31 | — | `Undo`, `History cleared`, `No recent searches or favorites` | `window.rb`, `history_sidebar.rb` | ported |
| 32–33 | — | `Toggle Favorite`, `Listen to Pronunciation` | `history_row.rb`, `pronunciation_row.rb` | ported |
| 34 | — | `Dismiss` | `error_dialog.rb` | ported |
| 35 | — | `Look up definitions of any English term` | `window.rb` | ported |
| 36–38 | — | `Paste & Search`, `_Random Word`, `_Preferences` | `main_menu.rb` | ported |
| 39–40 | — | `_Keyboard Shortcuts`, `_About Wordbook` | `main_menu.rb` | ported |
| 41–43 | — | `Source Code`, `Copyright © 2016-2026 Mufeed Ali`, `translator-credits` | `about_dialog.rb` | ported |
| 44–52 | shortcut window | `General`, `Show Shortcuts`, `Preferences`, `Paste and Search`, `Random Word`, `Search Selected Text`, `Toggle Sidebar`, `Show Menu`, `Quit` | `shortcuts_dialog.rb` | ported, with the context |

The mnemonic underscores are inside the msgids (`_Preferences`, not
`Preferences`), because a translator picks a mnemonic that works in their own
language.

`spec/wordbook/translations_spec.rb` asserts this table rather than describing
it: it scans every marker in `lib/`, parses every `.po`, and fails if a
catalogue key is unmarked, if a marked key is not in the catalogue, if the
fifteen languages do not hold the same message set, or if `POTFILES` names a
file that does not exist.

## Rows 53–63 — the eleven upstream never extracted

Eleven msgids live in upstream's `data/*.desktop.in.in` and
`*.metainfo.xml.in.in`: `dictionary;`, `Dark Mode`, `Dark mode`,
`Double click to search`, `Favorites`, `Features:`, `Fully offline`,
`Light Mode`, `Pronunciations`, `Random Word`, and
`Wordbook is an offline English-English dictionary application powered by
WordNet and eSpeak.`

**Upstream's `po/POTFILES` lists neither file.** `xgettext` has therefore never
read them, and no translator in any of the fifteen languages has ever been
offered them. This is an upstream extraction bug, found by this audit.

The port carries both files (`data/dev.mufeed.Wordbook.desktop.in`,
`data/dev.mufeed.Wordbook.metainfo.xml.in`) **and lists them in its own
`po/POTFILES`**, so the next extraction run offers all eleven. The merge path
exists too: `rake install:data` and `flake.nix` run
`msgfmt --desktop` / `msgfmt --xml` over them, which is what meson's
`i18n.merge_file` does for upstream — `Name[de]`, `Comment[ru]` and 45
`xml:lang` entries in the installed metainfo are there now.

**Owed upstream:** add `data/dev.mufeed.Wordbook.desktop.in.in` and
`data/dev.mufeed.Wordbook.metainfo.xml.in.in` to `po/POTFILES`. Not yet
reported; it is the one upstream bug this port can fix for upstream by
pointing at its own `POTFILES`.

## Keys the port adds

| msgid | Site | Why, and what is owed |
|---|---|---|
| `Ruby Port` | `about_dialog.rb` — the second About link | the port's own repository, so the code being run can be found. In no catalogue, so it renders in English everywhere. Not proposed upstream |
| `Did you mean: %s?` | `window.rb` | upstream builds this sentence by f-string interpolation (`window.py:371`), so it is in no catalogue and is still English in all fifteen languages. The port makes it a real key — `format(_("Did you mean: %s?"), links.join(", "))` — which is parity work on the *bug*, not on the string. **Owed upstream:** the same change at `window.py:371` |

Two keys the previous round added have been **removed**: the
`SettingsDialog` title "Preferences" and the `ShortcutsDialog` title
"Keyboard Shortcuts". Upstream sets no title on either dialog, so both were an
invented string *and* a visible header upstream does not have.

## Rules this port follows

1. never reword an upstream msgid to match a port literal. The 780
   translations are keyed on upstream's bytes;
2. never mark a context with a constant. `p_(CONTEXT, "Quit")` is unextractable
   and produced nine context-less keys here before it was caught — the context
   is written out at every call site;
3. never interpolate inside a marker. `#{}` runs before the marker can see the
   string, and the key would differ on every call;
4. strings in constants are marked with `N_` and looked up with `_()` at
   display time, so the catalogue is read after the locale is settled.
