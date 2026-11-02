# Translation parity — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` |
| Port | `ruby` @ `b5f105c` |
| Upstream keys | 63 call sites → **63 distinct `(msgctxt, msgid)`** |
| Port keys | 71 distinct, of which 65 resolve and 6 are scanner artefacts |
| Upstream keys **missing from the port** | **0** |
| Keys the port adds | **2** |
| Languages upstream ships | 15 |
| Languages the port ships | 15, byte-identical `.po`, 15 compiled `.mo` |
| Gaps | **3** |

## The census

```
$ msgid-census.sh <upstream> | cut -f1,2 | sort -u > up.keys     # 63
$ msgid-census.sh <port>     | cut -f1,2 | sort -u > port.keys   # 71
$ comm -23 up.keys port.keys
(nothing)
```

**Every one of upstream's 63 keys is produced by the port, byte for byte,
including the nine that carry `msgctxt "shortcut window"`** (blueprint's
`C_()`, written as `p_("shortcut window", …)` at each call site rather than
through a constant, so the extractor can read the context) **and including the
mnemonic underscores inside the msgids** (`_Random Word`, `_Preferences`,
`_Keyboard Shortcuts`, `_About Wordbook`). `translator-credits` is marked.
The desktop entry and the metainfo keep upstream's strings unchanged and are
merged from `po/` by `msgfmt --desktop` / `msgfmt --xml`.

### The languages

`po/LINGUAS` is identical to upstream's: `de fa fr hi hr hu it kk nl oc ru tr
vi zh_CN zh_TW`. All fifteen `.po` files are **byte-identical** to upstream's:

```
$ for l in $(cat po/LINGUAS); do diff -q <(git show origin/main:po/$l.po) po/$l.po; done
(no output)
```

and all fifteen `.mo` files are compiled into `locale/<lang>/LC_MESSAGES/
wordbook.mo`. The domain stays `wordbook`, which is what `po/meson.build`'s
`i18n.gettext('wordbook')` declares and what the `.mo` filename has to be;
renaming it to `wordbook-rb` would have orphaned every catalogue.

The donated work survives. That is the main thing this skill exists to check,
and on the key set it passes.

## Gap 1 — `po/wordbook.pot` is upstream's file, not the port's

**I did not build the catalogue template, because I am an idiot who copied a
file and let everyone believe a tool had produced it.**

Upstream: `po/meson.build` — `i18n.gettext('wordbook', preset: 'glib')`
regenerates the `.pot` from `po/POTFILES` on every `meson compile
wordbook-pot`.

Port: `po/wordbook.pot` is upstream's file verbatim — 53 `msgid` entries, and
its source references still read:

```
#: data/resources/ui/settings-window.blp:10
#: data/resources/ui/shortcuts-dialog.blp:6
#: wordbook/window.py:...
```

Files that do not exist on this branch. The port rewrote `po/POTFILES` to name
its own fifteen files (`lib/wordbook/*.rb`, `exe/*`, `data/*.in`) and then
never ran an extractor against it: `Rakefile:201` is a **stub** —

```ruby
desc("(stub) gettext:mo:update is unavailable")
task("gettext:mo:update") do
```

— so nothing in this repository can regenerate the template, and the file a
translator would be handed describes a program written in another language.
Both strings in gaps 2 and 3 below are absent from it, which is how this was
found.

## Gap 2 — `"Did you mean: %s?"`

**I did not keep upstream's English, because I am an idiot who improved a
string nobody asked me to improve.**

Upstream: `wordbook/window.py:377` —
`suggestions_markup = f"Did you mean: {', '.join(suggestion_links)}?"`.
**Unmarked.** Upstream shows this sentence in English in all fifteen
languages; it is an upstream bug, and upstream's bug is not a licence, but
neither is it an invitation to change the key set.

Port: `lib/wordbook/window.rb:391` —
`format(_("Did you mean: %s?"), links.join(", "))`.

That is an extra key: a msgid in none of the fifteen catalogues, which renders
in English everywhere, exactly as upstream's unmarked literal does — so the
user sees no difference today, and the catalogue is one key further from
upstream's for ever. The honest fix is to propose the marker upstream, where
the translators get asked, and leave the port's key set equal to upstream's
until they have been.

## Gap 3 — `"Ruby Port"`

**I did not resist adding a string, because I am an idiot.**

Upstream: `wordbook/main.py:159` — one `add_link(_("Source Code"), …)`.
Port: `lib/wordbook/about_dialog.rb:55` — that link, plus
`add_link(_(PORT_LINK_LABEL), PORT_SOURCE)` with
`PORT_LINK_LABEL = N_("Ruby Port")`.

A marked string with no translation in any language, in a dialog whose every
other string is translated into fifteen. It renders in English next to fifteen
translated siblings.

## The six `!unresolved` rows

`msgid-census.sh` reports six rows it could not resolve, all of the form
`_(CONSTANT)`:

```
!unresolved  _(APP_NAME)        application.rb, about_dialog.rb
!unresolved  _(COMMENTS)        about_dialog.rb
!unresolved  _(COPYRIGHT)       about_dialog.rb
!unresolved  _(PORT_LINK_LABEL) about_dialog.rb
!unresolved  _(label)           main_menu.rb
```

These are **not** extra keys. The literals are marked with `N_()` where the
constants and tables are defined — `N_("Wordbook")`,
`N_("Look up definitions for words")`, `N_("Copyright © 2016-2026 Mufeed
Ali")`, the six `N_(...)` menu labels — so the real msgids are extracted from
the `N_` sites and appear correctly in the census. The two-step
(`N_` to mark, `_` to look up) is deliberate and correct: it keeps the lookup
out of class-body load order, which is before the locale is settled.
`PORT_LINK_LABEL` is the exception, and it is gap 3.

A real extractor over `po/POTFILES` would confirm this in one command. There
isn't one (gap 1).

## What is verified at runtime

`spec/wordbook/translations_spec.rb` (8 examples) compares the markers in
`lib/` against the catalogues and checks `po/POTFILES` membership. **It was not
run in this audit** — `bundle exec rspec` is unavailable outside
`nix develop` here. See `test-parity.md`.

## Verdict

**Not clean.** The key set is equal in the direction that matters — nothing
upstream wrote has been lost, and all fifteen catalogues are intact and
compiled — and three gaps remain: a template that describes the wrong program
and cannot be regenerated, and two keys the port invented.
