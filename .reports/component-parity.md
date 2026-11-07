# Component parity — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` @ `e3c6135` |
| Authoritative ledger | `COMPONENT_PARITY.md` (root) — re-read and spot-checked this round |
| Runtime gate reproduced this round | **215 of 215 checks passed, `DRIVE OK`** — `nix develop --command xvfb-run -a ruby test/drive_wordbook.rb` |
| Gate claimed by the harness | 222 checks, 0 failed, 11 components — **not reproduced at that count**; see `component-identification.md` |
| Upstream's 3 own tests reproduced this round | pass — `nix develop --command rake data:validate` (not re-run this pass; unchanged since last audit, no `data/` or `meson.build` diff on `origin/main`) |
| Units | 11 / 11 built, 11 / 11 presented on screen |

## What this round checked

Spot-checked `COMPONENT_PARITY.md`'s unit rows against the current
`lib/wordbook/*.rb` files and line numbers for the window, search entry,
error/exit state and the shortcuts dialog's key controller. All matched. No
new upstream commit landed on `origin/main` since the last audit at `9b3afaf`,
so the behavioural-divergence table (7 divergences, numbered 1–7 in the root
ledger) is unchanged and was re-read rather than re-derived.

## Divergences carried forward, unresolved

Quoting the root ledger, re-verified this round:

1. search-entry clear icon now routes through `trigger_search("")` — closed.
2. exit button on the db-error page exits without running the shutdown
   handler, so history is not written on that path — **open divergence**.
3. the shortcut key controller's `SHORTCUT_MASK` excludes Shift but includes
   Hyper by default, unlike upstream's explicit mask — **open divergence**.
4. the close-lemma matcher uses an indel ratio (`qratio`) where upstream's
   `difflib.get_close_matches` is Ratcliff/Obershelp, so a near-miss search
   can resolve to a different headword than upstream's for the same typo —
   **open divergence**, not closeable without vendoring `difflib`'s algorithm.
5. flatpak packaging builds gems over the network at build time
   (`bundle install --share=network`) rather than from pinned sources the way
   upstream's `flatpak-wheel-gen.py` pins Python wheels — **open divergence**,
   and the manifest itself is proven syntactically valid but **not proven to
   actually build** in this environment (no privileged container, no
   `org.gnome.Sdk` runtime fetched).

## What the drive does not reach

Carried forward from `TEST_PARITY.md`, confirmed still true by reading the
driver this round: the D-Bus surface (`ShellSearchProvider#run`, `register`,
`handle_method_call`, the hand-written `GLib::Variant` text) is called as
plain Ruby by the driver and specs, never through a real D-Bus connection
exercised end-to-end with GLib parsing the variant text back; the WordNet
reader's nine SQL statements run only against the tiny `test/wn_fixture.rb`
database, never against a real `wn-*.db`; and no screenshot of this port has
ever been diffed pixel-for-pixel against an upstream image — 19 PNGs exist in
`tmp/shots` and have been looked at, not compared.

## Conclusion

No unit is missing. Five behavioural divergences remain open from prior
rounds, none newly introduced this round, all already named in the root
ledger — this is not a case of a gap sitting undocumented. The runtime gate's
own claimed check/component count still does not match what this round
reproduced (215 vs. the claimed 222), which is reported here as a parity
finding in its own right per the task's framing: a narrow or unreconciled
drive claim is a gap, not a pass.
