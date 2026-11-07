# Accountability ensurance — Wordbook-rb

Audit round. Grep re-run live against `lib/`, `exe/`, `.reports/` and
`PORTING.md`; findings cross-checked against source rather than accepted from
the documents' own prose.

## Grep sweep

```
$ grep -rn 'TODO\|FIXME\|not implemented\|for now\|in a future' lib exe PORTING.md .reports
```
No hit in `lib/` or `exe/`. The only hits anywhere are inside
`.reports/accountability-ensurance.md` itself — the pattern list and the
sentence explaining that `FINDINGS.md` quotes a `NotImplementedError` message
string that is deliberately distinguished from a real outstanding TODO. That
distinction was re-checked this round: `FINDINGS.md` quotes
`"NotImplementedError: TODO: in Ruby -> ..."` as the *text of an error Ruby
itself raises for an unimplemented stdlib method the port hit and worked
around*, not a marker the port left in its own code. Confirmed by reading the
surrounding `FINDINGS.md` paragraph; it is not a disguised gap.

**Clean on the literal pattern sweep.** No excuse-language hit in port code.

## The real finding this round: a stale root ledger, not a hedge phrase

The patterns above catch hedge *words*. They do not catch a document that
states a number that used to be true and is not anymore, with no hedge word
anywhere in the sentence — which is a more dangerous failure mode than a
"TODO", because it reads as a verified fact.

`PORTING.md`'s header table says:

> Open gaps | **1 component, 0 test, 1 translation**

and its "Translation gaps (1)" section names only `"Ruby Port"`. The root
`TRANSLATION_PARITY.md` repeats "Extra | **1**". Both are wrong **right now**:
re-deriving the key-set diff directly against `origin/main` this round (see
`.reports/translation-parity.md`) finds **12** port-only msgids, not 1. The
previous round's own `.reports/translation-parity.md` had already found and
written down the 12 — correctly, with the `comm` command and its output
shown — but that finding was never carried into `PORTING.md` or
`TRANSLATION_PARITY.md`, both of which still say 1 after `665cb58` ("Parity
reports", the commit that last touched `.reports/translation-parity.md`) was
already on the branch.

This matters more than a `TODO` would, for the reason this skill exists: the
next agent to work this port reads `PORTING.md` first — the file's own header
says so ("Resume point for the next run") — and `PORTING.md` told it the
translation gap was closed down to one deliberate, documented exception. It
is not. A reader who trusted the header and moved on would have inherited an
11-string undercount as settled fact, exactly the console-rb failure mode
this skill's own description cites, just with numbers instead of a "Dropped
deliberately" heading.

Also minor, same shape: root `TEST_PARITY.md` states the driver as "210
checks, all passing"; this round's live run (and the preceding round's
`.reports/test-parity.md`) both show 215. Lower stakes than the translation
figure — it understates the port's own verified strength rather than
overstating completeness against upstream — but it is the same pattern: a
root document not re-synced with the `.reports/` figure that superseded it.

## Nothing else found excused

- No "dropped deliberately", "out of scope", "by design", "simplified", or
  "n/a" sentence found anywhere in `PORTING.md`, `FINDINGS.md`, `README.md`,
  or in `lib/`/`exe/` comments on this pass (`grep -in 'deliberately\|out of scope\|by design\|n/a\b'` over those files returns nothing in `lib/`/`exe/`; `PORTING.md`'s own uses of "deliberately" are about the kept `"Ruby Port"` extra key, which is disclosed with its exact site and reason, not a hedge for unbuilt work).
- The one component gap `PORTING.md` does list (no pre-built dictionary
  shipped) is upstream's own behaviour too (`meson_options.txt`'s
  `install_wn_db` defaults off) and is backed this round by the drive run
  actually hitting "No compressed database found" in both the rspec run and
  the live driver's logs — a real, observed absence, not an assertion.
- The suite and driver are not "never executed" claims resting on an old log:
  both were re-run live this session (see `.reports/test-parity.md`) and
  produced the exact figures now cited.

## Verdict

**Not clean.** One concrete false-green: the root ledger's translation-gap
count (1) is superseded by the port's own most recent, correctly-run audit
(12), and the root ledger was never corrected to match. This is the kind of
gap this skill exists to name — not missing code, but a settled-sounding
number that stopped being true and nobody went back to fix.
