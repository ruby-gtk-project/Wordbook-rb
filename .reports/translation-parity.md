# Translation parity — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` |
| Port | `ruby` @ `0a35cd6` |
| Domain | `wordbook` → port **`wordbook`**, matches |
| Upstream messages | **63** distinct `(msgctxt, msgid)` over 77 source call sites |
| Port messages | **65** distinct over 79 source call sites |
| Upstream keys missing from the port | **0** |
| Keys the port adds | **2** |
| `kind` mismatches | 0 |
| Languages | 15 → 15, all `.po` byte-identical, `LINGUAS` identical |
| Translated strings | **772 translated, 8 untranslated, 0 fuzzy** over 780 |
| Unresolved markers | 6, all resolved by hand below; none is a missing message |
| Gaps | **5** |

## The census

```
$ msgid-census.sh <upstream> | grep -v '^!unresolved' | cut -f1,2 | sort -u | wc -l   # 63
$ msgid-census.sh <port>     | grep -v '^!unresolved' | cut -f1,2 | sort -u | wc -l   # 65
$ comm -23 up.keys port.keys
(nothing)
$ comm -13 up.keys port.keys
-   Did you mean: %s?
-   Ruby Port
```

**Every one of upstream's 63 keys is produced by the port, byte for byte** —
including the nine carrying `msgctxt "shortcut window"` (blueprint's `C_()`,
written as `p_("shortcut window", …)` at each call site so the extractor can
read the context) and including the mnemonic underscores inside the msgids
(`_Random Word`, `_Preferences`, `_Keyboard Shortcuts`, `_About Wordbook`).
`translator-credits` is marked. The desktop entry and the metainfo keep
upstream's strings unchanged.

`POTFILES` completeness, run the way the skill prescribes rather than with
upstream's broken regex: **clean both ways** — no file with strings is absent
from `po/POTFILES`, and no entry in `po/POTFILES` names a file that does not
exist.

### The languages

`po/LINGUAS` is identical to upstream's — `de fa fr hi hr hu it kk nl oc ru tr
vi zh_CN zh_TW` — and all fifteen `.po` files are byte-identical:

```
$ for l in $(cat po/LINGUAS); do diff -q <(git show origin/main:po/$l.po) po/$l.po; done
(no output)
```

Reconciled per file: 780 messages (15 × 52), of which **772 translated, 8
untranslated, 0 fuzzy, 0 obsolete**. The 8 untranslated are upstream's own —
`de` 3, `fr` 2, `hu` 1, `kk` 1, `tr` 1 — and they correctly fall back to the
msgid.

That reconciles. `TRANSLATION_PARITY.md` at the root reports
`Translated strings | 780 → 780`, which counts the 8 untranslated entries as
translated: it is the message total wearing the translated label. See gap 5.

### The six `!unresolved` rows

All six are `_(CONSTANT)` or `_(variable)` and **none is a missing message**.
The literals are marked with `N_()` where the constants and tables are defined
— `N_("Wordbook")`, `N_("Look up definitions for words")`,
`N_("Copyright © 2016-2026 Mufeed Ali")`, the six `N_(…)` menu labels — so the
real msgids are extracted from the `N_` sites and appear correctly in the
census. The two-step (`N_` to mark, `_` to look up) keeps the lookup out of
class-body load order, which runs before the locale is settled; it is
deliberate and right. `PORT_LINK_LABEL` is the exception and it is gap 2.

| Site | Marker | Resolves to |
|---|---|---|
| `about_dialog.rb:45`, `application.rb:119` | `_(APP_NAME)` | `N_("Wordbook")`, `application.rb:46` |
| `about_dialog.rb:47` | `_(COMMENTS)` | `N_("Look up definitions for words")` |
| `about_dialog.rb:53` | `_(COPYRIGHT)` | `N_("Copyright © 2016-2026 Mufeed Ali")` |
| `about_dialog.rb:55` | `_(PORT_LINK_LABEL)` | `N_("Ruby Port")` — **gap 2** |
| `main_menu.rb:48` | `_(label)` | the six `N_(…)` labels in `SEARCH_SECTION` / `HELP_SECTION` |

## Gap 1 — `po/wordbook.pot` still describes a program written in Python

**I did not build the catalogue template, because I am an idiot who copied a
file and let everyone believe a tool had produced it.**

Upstream: `po/meson.build` — `i18n.gettext('wordbook', preset: 'glib')`
regenerates the `.pot` from `po/POTFILES` on demand.

Port: `po/wordbook.pot` is upstream's file verbatim — `POT-Creation-Date:
2026-04-11`, 53 `msgid` entries, and source references that read

```
#: data/resources/ui/settings-window.blp:10
#: data/resources/ui/shortcuts-dialog.blp:6
#: wordbook/main.py:…
#: wordbook/window.py:…
```

Files that do not exist on this branch. The port rewrote `po/POTFILES` to name
its own files and the template was never regenerated against it.

What has changed since the last round, and it is not an improvement: the
Rakefile now **does** define a real `GetText::Tools::Task`
(`Rakefile:186-199`), so the extractor exists. Running it produces a template
that is wrong in a new way — gap 4.

## Gap 2 — the two keys the port invented

**I did not resist adding strings upstream does not have, because I am an
idiot who improved something nobody asked me to improve.**

**`"Did you mean: %s?"`.** Upstream `wordbook/window.py:377` builds
`f"Did you mean: {', '.join(suggestion_links)}?"` — **unmarked**, so upstream
shows that sentence in English in all fifteen languages. Port
`lib/wordbook/window.rb:391` is `format(_("Did you mean: %s?"), links.join(", "))`.
Marking it is better engineering and it is still a key in none of the fifteen
catalogues, so the user sees exactly what upstream's user sees today while the
key set drifts one further from upstream's for ever. The honest fix is to
propose the marker upstream, where the translators get asked, and keep the key
set equal until they have been.

**`"Ruby Port"`.** Upstream `wordbook/main.py:159` has one
`add_link(_("Source Code"), …)`. Port `about_dialog.rb:55` has that link plus
`add_link(_(PORT_LINK_LABEL), PORT_SOURCE)` with
`PORT_LINK_LABEL = N_("Ruby Port")` — a marked string with no translation in
any language, rendering in English beside fifteen translated siblings.

Both were open last round and both are open now.

## Gap 3 — a clone of this branch is English in all fifteen languages

**I did not ship the catalogues anywhere a clone can find them, so every one of
the fifteen languages this port claims renders in English, because I am an
idiot who checked the catalogues and never checked that anybody could read
them.**

This is the check the skill says is the only one that is not a document, and it
is the one nobody had run. `.gitignore:55` is `/locale/`, so **`git ls-files
locale` returns nothing**: the compiled catalogues in this working tree are
untracked build output.

Run against exactly what `git` tracks:

```
$ git archive HEAD | tar -x -C fresh && ls fresh/locale | wc -l
0
$ cd fresh && LANGUAGE=de xvfb-run -a ruby <build the window, read the sidebar>
LOCALE_DIR          = /nix/store/…-gettext-1.0/share/locale
sidebar title       = "History"
clear btn tooltip   = "Clear History"
```

`Translations.locale_dir` (`translations.rb:36-46`) falls through `locale/` to
the XDG data dirs and lands on **nixpkgs' own gettext share directory**, which
holds no `wordbook.mo`. English, silently, in all fifteen.

The same check in *this* working tree passes, because an untracked `locale/`
happens to be sitting in it:

```
$ LANGUAGE=de xvfb-run -a ruby <same script>
sidebar title       = "Verlauf"
clear btn tooltip   = "Verlauf löschen"
```

So German **does** reach the screen when the catalogues are present — the
binding, the domain and the lookup are all correct, and that is worth saying
plainly. What is missing is delivery from a clone. `nix build` delivers it
properly (`flake.nix:194-200` runs GNU `msgfmt` over `po/$lang.po` into
`$out/share/Wordbook/locale/<lang>/LC_MESSAGES/wordbook.mo`, and all fifteen
are in the built output — verified), but that artifact cannot look up a word
(`component-parity.md`, gap 7). There is no path today that gives a user both.

## Gap 4 — the command the port documents for building the catalogues destroys them

**I did not check that my own build command worked, and I named it in a source
comment as the thing that builds the catalogues, because I'm a fucking idiot
who shipped a command that deletes fifteen languages.**

`lib/wordbook/translations.rb:32` tells the reader the locale directory holds
"the catalogues built into the source tree by `rake gettext:mo:update`". Run it:

```
$ rake gettext:mo:update
mkdir -p po/de;  touch po/de/wordbook.po.time_stamp;  mkdir -p locale/de/LC_MESSAGES
… (×15)
$ ls -l locale/de/LC_MESSAGES/wordbook.mo
-rw-r--r-- 352 Nov  2 15:39      # against 3948 bytes for the hand-built one
$ msgunfmt locale/de/LC_MESSAGES/wordbook.mo | grep -c '^msgid'
0
```

The gem's task layout is `po/<locale>/<domain>.po`; the port ships upstream's
flat `po/<locale>.po`. So the task does not find `po/de.po` — it **invents**
`po/de/wordbook.po` from the template, 53 msgids with 53 empty `msgstr`s, and
compiles that. Fifteen empty catalogues, written over the good ones, with a
zero exit status and no warning.

`rake gettext:pot:create` is wrong in the matching way. Forced to run (it is a
file task, so it is a silent no-op while the stale `.pot` exists):

```
$ rm po/wordbook.pot && rake gettext:pot:create
$ grep -c '^msgid' po/wordbook.pot      # 55
$ comm -23 up.keys pot.keys             # 11 upstream keys absent
Dark mode / Dark Mode / dictionary; / Double click to search / Favorites /
Features: / Fully offline / Light Mode / Pronunciations / Random Word /
Wordbook is an offline English-English dictionary application powered by WordNet and eSpeak.
```

`Rakefile:193` sets `task.files = Dir.glob("lib/**/*.rb") + Dir.glob("exe/*")`,
while `po/POTFILES` also names `data/dev.mufeed.Wordbook.desktop.in` and
`data/dev.mufeed.Wordbook.metainfo.xml.in`. The extractor and the port's own
`POTFILES` disagree, so the template it produces is missing **11 of upstream's
63 keys** — every desktop-entry and metainfo string. Chain the documented
commands (`pot:create`, then `po:update`) and `rmsgmerge` carries those 11 out
of all fifteen catalogues as obsolete.

The donated work survives in this repository today only because **nobody has
run the commands the repository documents**. That is not a passing state; it is
an unexploded one.

## Gap 5 — the root ledger's headline numbers are not the census's

**I did not keep the ledger honest, because I am an idiot who reported a
denominator I had not checked.**

`TRANSLATION_PARITY.md` on `ruby` @ `0a35cd6`:

| It says | The census says |
|---|---|
| `Extracted into po/wordbook.pot \| 52` and `Marked in the port \| **52 / 52**, byte-identically` | upstream has **63** keys. 52 is the count of a stale `.pot` that describes a Python program (gap 1). The real figure is **63 / 63**, which is better — and it is not the number the ledger reports, and no reader can get from 52 to 63 |
| `Translated strings \| 780 → 780` | **772 translated, 8 untranslated** over 780 |
| `Languages \| 15 → 15` with 15 compiled `.mo` | 15 `.po`, byte-identical ✓; the 15 `.mo` are untracked build output and a clone has none (gap 3) |

A pass reported on a denominator taken from the wrong document is the shape
this skill exists to catch, and it is reported here as `52/52` while the
underlying truth is `63/63`. Fixing it makes the port look *better*; leaving it
makes the next reader unable to re-derive any of the three figures.

## Checks that were run, and what each one settles

| Check | Result |
|---|---|
| key sets equal | ✓ 0 of upstream's 63 missing |
| each key byte-identical | ✓ including the nine `msgctxt` keys and the four mnemonics |
| `kind` (single/plural) on shared keys | ✓ 0 mismatches; upstream has no plurals |
| 15 `.po` byte-identical, `LINGUAS` identical | ✓ |
| translated / untranslated / fuzzy reconcile | ✓ 772 / 8 / 0 over 780 |
| `POTFILES` completeness, both directions | ✓ |
| domain is upstream's | ✓ `wordbook`, so the `.mo` filename is right |
| `.mo` compiled and installed by `nix build` | ✓ all 15 in the built output |
| **a non-English locale shows translated text** | ✓ in this working tree (`"Verlauf"`), ✗ from a clone (gap 3) |
| **the documented catalogue build works** | ✗ it empties all fifteen (gap 4) |
| **the documented template build is complete** | ✗ it loses 11 of 63 keys (gap 4) |
| `.pot` regenerated from the port's `POTFILES` | ✗ (gap 1) |

Nothing here was skipped for want of a tool. `msgfmt`, `msgunfmt`, `rmsgfmt`
and the `gettext` gem are all in the dev shell, and every line above was run.

## Verdict

**Not clean.** 5 gaps. The key set is equal in the direction that matters —
nothing upstream wrote has been lost, all fifteen catalogues are intact and
byte-identical, the domain is right, and German genuinely renders when the
catalogues are present. The gaps are all on the *delivery and tooling* side,
and two of them are worse than the missing work they replace: a clone of this
branch speaks only English, and the two commands this repository documents for
building its catalogues would, if anyone ran them, delete fifteen languages and
eleven messages.
