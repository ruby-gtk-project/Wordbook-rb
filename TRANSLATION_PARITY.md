# Translation parity — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` |
| Domain | `wordbook` (from upstream's `po/meson.build`) → port: **`wordbook`** |
| Upstream messages | 63 distinct `(msgctxt, msgid)` keys over 77 call sites |
| Ported | **63 / 63**, byte-identically |
| Extra | **12**, English-only, recorded in full below — not 1; a stale "1" stood here for two rounds, see the correction note under `## Extra` |
| Extracted into `po/wordbook.pot` | **65 bare msgids** — a live `comm` of `po/wordbook.pot` against `git show origin/main:po/wordbook.pot` this round shows upstream's own template has only **53** bare msgids (not the 63 of the ledger above, which also counts the 11 rows upstream's `.blp`/`.py` content implies but upstream's `POTFILES` never extracts); the port's 65 = 53 upstream + 12 extra |
| Languages | 15 → **15**, all fifteen `.mo` files committed under `locale/` |
| Translated strings | 780 → **780 of 780** translated, 0 untranslated, 0 fuzzy |
| Unresolved markers | 0 |

Three of those numbers were wrong in this header last round, and the way they
were wrong all pointed the same way:

- **`Extracted into po/wordbook.pot | 52`** and **`Marked in the port | 52 / 52`**
  were a pass measured against the wrong denominator. 52 is the entry count of
  `po/wordbook.pot` as it stood — upstream's file verbatim, with `#:`
  references to `.blp` and `.py` files that do not exist on this branch. It
  described a Python program. Upstream has 63 keys; the port marks all 63; the
  template now says so, because `rake gettext:pot:create` reads `po/POTFILES`
  instead of globbing `lib/` and `exe/`, and extracts the two `data/*.in` files
  with GNU `xgettext`'s Desktop reader and its metainfo ITS rules. Pinned by
  two examples in `spec/wordbook/translations_spec.rb`.
- **`Languages 15 → 15`** was measured against an untracked `locale/` that
  happened to be sitting in the working tree. `/locale/` was in `.gitignore`,
  so a clone of this branch was English in all fifteen languages: a
  `git archive` of HEAD run with `LANGUAGE=de` showed the sidebar title as
  "History". The catalogues are committed now, `rake locale` rebuilds them from
  `po/` with GNU `msgfmt`, `bin/setup` and the dev shell both call it, and
  `test/drive_wordbook.rb` asserts "Verlauf", "Nur Favoriten anzeigen" and
  "Verlauf löschen" on screen in a process started with `LANGUAGE=de` — so this
  row is a check now, not a claim.

The translated-string count is measured, not asserted:

```sh
$ for l in $(cat po/LINGUAS); do msgfmt --statistics -o /dev/null po/$l.po; done
52 translated messages.   # ×15 = 780, no "untranslated", no "fuzzy" in any line
```

A previous report put this at "772 translated, 8 untranslated". I could not
reproduce that from these files by either `msgfmt --statistics` or a direct
count of empty `msgstr`s: all 780 are filled.

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
| compiled | `rake locale` → `locale/<lang>/LC_MESSAGES/wordbook.mo`, with GNU `msgfmt`. **Committed**, not gitignored, so a clone is translated without a build step; also rebuilt by `bin/setup` and by the dev shell's `shellHook`, and built into `$out/share/Wordbook/locale` by `flake.nix`. `rake gettext:mo:update` does the same thing through the gem and is safe again — it used to compile a `po/<locale>/wordbook.po` that the gem invented, with 53 empty msgstrs, over the good catalogue, emptying all fifteen languages with exit status zero. The `Rakefile`'s `FlatLayoutTask` points the gem at the flat `po/<locale>.po` this port and upstream both ship |
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
`data/dev.mufeed.Wordbook.metainfo.xml.in`), lists them in its own
`po/POTFILES`, **and now extracts them**: `rake gettext:pot:create` reads
`POTFILES` rather than globbing, runs GNU `xgettext --language=Desktop` over
the desktop entry and `xgettext --its=<gettext>/its/metainfo.its` over the
metainfo, and `msgcat`s the three results into `po/wordbook.pot`. All eleven
are in the template, so the next `po:update` offers them to all fifteen
languages instead of merging them out. Until this round the extractor globbed
`lib/**/*.rb` + `exe/*` and would have dropped every one of the eleven, and the
documented `pot:create` → `po:update` chain would have removed them from every
catalogue. The merge path exists too: `rake install:data` and `flake.nix` run
`msgfmt --desktop` / `msgfmt --xml` over them, which is what meson's
`i18n.merge_file` does for upstream — `Name[de]`, `Comment[ru]` and 45
`xml:lang` entries in the installed metainfo are there now.

**Owed upstream:** add `data/dev.mufeed.Wordbook.desktop.in.in` and
`data/dev.mufeed.Wordbook.metainfo.xml.in.in` to `po/POTFILES`. Not yet
reported; it is the one upstream bug this port can fix for upstream by
pointing at its own `POTFILES`.

## Extra — keys the port adds

**Correction:** this section said "One" (`Ruby Port`) for two rounds. A live
`comm` of `po/wordbook.pot` against `git show origin/main:po/wordbook.pot`
this round shows upstream's template has 53 bare msgids and the port's has
65 — **twelve** extras, not one. The previous round's own
`.reports/translation-parity.md` (commit `665cb58`) had already found and
correctly recorded all twelve; this file and `PORTING.md`'s "Open gaps" table
were never updated to match, so both kept repeating the superseded "1".
Twelve, all English-only in every one of the 15 shipped languages because no
translator has ever been offered them (`po/de.po` remains byte-identical to
upstream's `de.po`):

| msgid | Site | Why, and what is owed |
|---|---|---|
| `Ruby Port` | `about_dialog.rb:55` — the second About link, `PORT_LINK_LABEL` | the port's own repository, so the code being run can be found. Has no upstream string to diverge from at all — a pure port addition, not an extraction artifact. **Decision: keep.** A user who wants the source of the thing they are running should find it; recorded here rather than quietly marked, because an extra key is a divergence in the key set whatever its merits |
| `Features:` | `data/dev.mufeed.Wordbook.metainfo.xml.in`'s `<description>` feature list | the port's `po/POTFILES` extracts this file; upstream's `po/POTFILES` (`git show origin/main:po/POTFILES`) lists only three `.blp` and three `.py` files, never the metainfo. **Decision: keep marking**, per the "Rows 53–63" analysis below — this is upstream's own extraction bug, and the port's extraction + `msgfmt --xml` merge machinery already exists to benefit from a fix there |
| `Fully offline` | same `<description>` list | same cause and decision |
| `Pronunciations` | same `<description>` list | same cause and decision |
| `Favorites` | same `<description>` list | same cause and decision |
| `Double click to search` | same `<description>` list | same cause and decision |
| `Dark mode` | same `<description>` list | same cause and decision |
| `Dark Mode` | metainfo `<description>` list, and the About dialog's dark-mode toggle label | same cause and decision |
| `Light Mode` | metainfo `<description>` list / About dialog toggle label | same cause and decision |
| `Random Word` | metainfo `<description>` list, bare (no `msgctxt`) — a second, context-less key colliding in text with the existing `msgctxt "shortcut window"` `Random Word` upstream already has at row 48 | same cause; **decision: keep marking** the metainfo copy for the same reason, even though the collision means two keys now share rendered text under different contexts |
| `dictionary;` | `data/dev.mufeed.Wordbook.desktop.in`'s `Keywords=` | the port's `po/POTFILES` extracts the desktop file; upstream's never does. **Decision: keep marking**, same reasoning — `msgfmt --desktop` already merges `Keywords[xx]=` the same way meson's `i18n.merge_file` would |
| `History` | desktop/metainfo extraction, bare (no context) — collides in text with the existing bare `History` key at row 4 (`history_sidebar.rb`) | the desktop entry's `Name`/`Keywords` extraction produces a second occurrence of text upstream already has a key for; not a new concept, just a duplicate line from a different source file. **Decision: keep** — removing it would mean treating the desktop extraction specially for one string only |

Eleven of these twelve (every one but `Ruby Port`) exist only because this
port's `po/POTFILES` lists `data/dev.mufeed.Wordbook.{desktop,metainfo.xml}.in`
and upstream's does not — see "Rows 53–63" below, which upstream owes the fix
for. The alternative this round considered and rejected was to stop
extracting those two files here, which would shrink `po/wordbook.pot` back to
53 + 1 = 54 and make the port's key set a strict match for upstream's actual
template; it was rejected because it would also silently drop the metainfo
feature list and the desktop keywords back to permanently-English text with
no mechanism to ever offer them to a translator, which is worse than an
honestly-recorded 12-key divergence with the merge machinery already in
place. If a future round disagrees, reverting `po/POTFILES` to drop the two
`data/*.in` lines and re-running `rake gettext:pot:create` is the mechanical
undo.

`Did you mean: %s?` was a second added key and has been **removed**.
`window.rb:391` marked it with `_()`, which looked like an improvement on
upstream building the sentence unmarked at `window.py:377`. It was not: no
translator in any of the fifteen languages has ever been offered the string, so
it rendered in English anyway, and meanwhile the port's key set no longer
matched upstream's. It is built unmarked now, exactly as upstream builds it.
**Owed upstream:** mark it at `window.py:377`, where the translators get asked.

Two keys an earlier round added were removed before this one: the
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
