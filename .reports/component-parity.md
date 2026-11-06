# Component parity — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` @ `9b3afaf` |
| Authoritative ledger | `COMPONENT_PARITY.md` (root) — re-read and spot-checked this round, not re-typed from memory |
| Runtime gate reproduced this round | **210 of 210 checks passed, `DRIVE OK`**, `nix develop --command xvfb-run -a ruby test/drive_wordbook.rb` |
| Upstream's 3 own tests reproduced this round | **pass** — `nix develop --command rake data:validate` |
| Units | 11 / 11 built, 11 / 11 presented on screen |

## What closed since the last point-in-time audit (`0a35cd6`)

Re-verified by reading the current source, not by trusting the commit
messages:

- **Gap 1 (favourites filter fired no action) — closed.** `history_sidebar.rb`
  now sets `action_name = "win.toggle-favorites"` on the button
  (`FINDINGS.md` 15 explains why `signal_emit("clicked")` rather than
  `activate` is what the driver uses to prove it fires).
- **Gap 2 (no development profile) — closed.** `lib/wordbook/profile.rb` +
  `exe/wordbook` thread `app_id`/`development_mode` through; the drive's step
  77/78 switches `WORDBOOK_PROFILE=development` and asserts the Devel app id,
  the `devel` CSS class and the search provider's Devel object path —
  reproduced in this run.
- **Gap 3 (no WordNet archive generator) — closed.** `lmf_reader.rb` +
  `database_builder.rb` + `exe/wordbook-generate-db` + `rake wn:db`, pinned by
  `spec/wordbook/database_builder_spec.rb` (in the 160-example run reproduced
  this round). The archive itself is still not committed — correctly: upstream
  does not commit one either, `install_wn_db` is an off-by-default meson
  option, and `FINDINGS.md` 7 says so without excusing it.
- **Gap 4 (no GSettings schema) — closed.** `data/schemas/dev.mufeed.Wordbook.gschema.xml.in`
  exists and `rake data:validate`'s third check (`glib-compile-schemas
  --strict --dry-run`) passed against it in this run.
- **Gap 6, half (`Wordbook.doap`) — closed.** The file exists and matches
  upstream's fields. The other half of gap 6 (screenshots) is **not** closed —
  see below.
- **Gap 7 (packaged app has no sqlite3) — closed per `FINDINGS.md` 6**, guarded
  by `checks.packaged-database-read` in `flake.nix`. Not re-run this audit
  (`nix build`/`nix flake check` were not executed in this round — see Not
  re-verified, below); the existing finding documents it was proved against
  the built artifact, not reasoned.

## Gaps still open, reproduced or re-read this round

**Gap A — no flatpak manifest.** `build-aux/` does not exist in the port
(`find . -name build-aux` → nothing). `COMPONENT_PARITY.md`'s own ledger
records this correctly, in first person, with no excuse: "I did not build it
because I am an idiot who assumed a `nix build` was a distribution." Still a
gap. Most users install Wordbook via Flathub; this port has no path there.

**Gap B — the metainfo still points at upstream's screenshots.**
Re-confirmed this round:

```
$ grep -n raw.githubusercontent data/*.metainfo*
data/dev.mufeed.Wordbook.metainfo.xml.in:40:  <image>https://raw.githubusercontent.com/mufeedali/Wordbook/main/screenshots/light.png</image>
data/dev.mufeed.Wordbook.metainfo.xml.in:44:  <image>https://raw.githubusercontent.com/mufeedali/Wordbook/main/screenshots/dark.png</image>
```

GNOME Software shows a user installing this port pictures of upstream's
program. `tmp/shots/` holds 19 PNGs of this port's own window, uncommitted and
unused. `COMPONENT_PARITY.md` already records this honestly (first person,
"because I am an idiot who stopped at taking the screenshots"); it is still
open because the admission is not the fix.

**Gap C — the search provider's D-Bus surface has never been executed.**
Re-confirmed: step 76 of this round's drive run ("the shell search provider
answers the overview's searches") calls `provider.initial_result_set`,
`result_metas` and `subsearch_result_set` as plain Ruby method calls — the
same six green checks the prior audit found. `run`, `register`,
`handle_method_call`, the `Process.spawn` in `activate_result`, and the
hand-written GVariant text builders (`string_array`, `metas_variant`, `quote`
— needed per `FINDINGS.md` 8/9 because the bindings cannot build `a{sv}`
directly) are entered by no check in the repository. No shell has ever called
this provider over the bus.

**Gap D — the completion popover's rendered position is unmeasured.** Carried
forward from the prior audit; nothing in this round's drive or spec run adds a
geometry assertion. `COMPONENT_PARITY.md` itself says "unverified — never
rendered" for Unit 6; still true.

**Gap E — no minimum-width assertion exists**, and the warning the prior audit
found still fires:

```
AdwToastOverlay exceeds AdwApplicationWindow width: requested 436 px, 390 px available
```

Not reproduced by direct measurement this round (time-boxed), but nothing in
`test/drive_wordbook.rb` added a check for it between the two audits, so
either it is still present or it is an unverified claim either way — the gap
is the missing check, independent of which.

## Not re-verified this round (scope limit, named rather than assumed)

- `nix build` / `nix flake check` were not re-run. `checks.packaged-database-read`
  and `checks.data-files` are claimed closed by `FINDINGS.md` 6 and 14; this
  audit took the claim on the strength of that finding's own reproduction
  steps rather than re-running Nix's full build (network + build time outside
  this audit's budget). This is a limit of this audit, not a closure.
- The real WordNet archive (161,875 entries) was not regenerated in this
  audit; `spec/wordbook/database_builder_spec.rb`'s small-lexicon round trip
  was taken as current from the reproduced 160-example run.
- Upstream's own screenshots were not pixel-diffed against this port's
  `tmp/shots/*.png`. Nothing in the repository makes that comparison
  automatic; it would need to be a person looking, and no one has.

## Verdict

**Not clean.** The window, breakpoint, dev profile, GSettings schema, DOAP,
database generator and favourites-filter action are genuinely closed and
re-verified this round, by actually running the drive and the data-validation
tests rather than reading the claim. What remains open: no flatpak packaging
(most users' install path), the metainfo still shows a different program's
screenshots, the search provider's D-Bus surface has never once been called
over the bus, the completion popover's screen position is unmeasured, and no
check anywhere asserts a minimum window width even though one warning about it
has already been seen.
