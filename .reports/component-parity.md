# Component parity — Wordbook-rb

Audit round — re-derived, not carried forward.

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` |
| Port | `ruby` @ `d3c3f60` |
| Authoritative port ledger | `COMPONENT_PARITY.md` (root) |
| Runtime gate reproduced this round | **215 of 215 checks passed, `DRIVE OK`** (`nix develop --command xvfb-run -a ruby test/drive_wordbook.rb`, run live for this audit, matching the stated gate exactly) |
| rspec suite reproduced this round | **160 examples, 0 failures** |

## What was re-checked against source, not against the ledger's prose

For each of the 11 units, the port file and the upstream `.blp`/`.py` pair it
claims were both opened this round:

| Unit | Port | Upstream | Spot-check |
|---|---|---|---|
| 1 Main window | `window.rb` | `window.blp` template + `window.py` | `Adw::Breakpoint`, `max-width: 550px` condition present both sides |
| 2 App menu | `main_menu.rb` | `window.blp:4-42` | same 6 items incl. separators, same `action-name`s |
| 3 History sidebar | `history_sidebar.rb` | `window.blp:61-145` + `window.py` | `win.toggle-favorites` filter button present both sides |
| 4 History row | `history_row.rb` | row builder in `window.py` | same widget set per row |
| 5 Definition cluster | `definition_view.rb`/`definition_row.rb`/`pronunciation_row.rb`/`relation_box.rb` | `window.blp:224-236` + `_populate_definitions`/`_create_*` | same widget set, 4 files to upstream's 1 cluster |
| 6 Search completion | `search_completion.rb` | `search_completion.py` | same `notify::selected` signal |
| 7 Preferences | `settings_dialog.rb` | `settings-window.blp` + `settings_window.py` | 5 rows both sides |
| 8 Shortcuts | `shortcuts_dialog.rb` | `shortcuts-dialog.blp` | all 8 rows, both sides |
| 9 Application | `application.rb`/`profile.rb`/`exe/wordbook` | `main.py` + `meson.build:40-50` | devel/stable app-id switch confirmed live by this round's own driver run |
| 10 Search provider | `shell_search_provider.rb` + `exe/wordbook-search-provider` | `data/search_provider.in` | D-Bus object path and all 5 `SearchProvider2` methods — **re-run live this round over a real session bus, three times in a row; see below, this is new work this round, not a carry-forward** |
| 11 Error alert | `error_dialog.rb` | `_new_error` in `window.py` | same banner widget and dismiss action |

## New this round: the search-provider D-Bus surface was actually exercised, and it is not reliably green

Prior rounds' reports carried this unit forward as "not re-run" or cited a
single passing run. This round ran `test/drive_search_provider_dbus.rb`
(a real session bus via `dbus-run-session`, a real provider subprocess, real
`gdbus call`s over the socket) **three consecutive times**:

```
run 1: 7 of 7 checks passed — DBUS DRIVE OK
run 2: 7 of 7 checks passed — DBUS DRIVE OK
run 3: 1 of 7 checks passed — DBUS DRIVE FAILED (6)
```

Root cause, isolated live: `check("the bus name is owned within 10s")`
passes once `org.freedesktop.DBus.NameHasOwner` returns true, but the
provider's `register()` of the actual object at
`/dev/mufeed/Wordbook/SearchProvider` can still be in flight at that instant
— owning the bus name and registering the object are two separate D-Bus
calls in `shell_search_provider.rb`/`exe/wordbook-search-provider`, and
nothing in the driver or the provider waits for the second one. When
`gdbus introspect` (step 2) lands in that gap, `Introspect` fails, and every
later numbered check cascades to failure because each one depends on a
result id produced by the step before it. This is a real race in the
driver/provider interaction, not a flake in the test tooling (`gdbus`,
`dbus-run-session`) — confirmed by re-running the same binary three times
back to back with no other change.

This means Unit 10's "D-Bus surface" is **not** unconditionally verified by
this driver the way `PORTING.md`'s "Open gaps" section currently implies
(see `accountability-ensurance.md` for the exact quote and why it is a
false-green). The methods themselves are implemented correctly — every run
that gets past the race passes all 7 checks, including the two write paths
(`ActivateResult`, `LaunchSearch`) — but "the D-Bus surface has never been
run" being marked **closed** overstates what one flaky driver proves.

## The translation axis (carried forward, unchanged this round)

Component parity requires a fourth axis — the same translatable strings —
beyond widget/CSS/signal parity. See `translation-parity.md`: 12 port-only
msgids (units 1, 7, 9's strings) with no upstream msgid behind them, found
in a prior round, re-confirmed unchanged by this round's own `comm` diff
(53 upstream / 65 port, identical to the last two rounds). This does not
change any of the 11 units' widget/CSS/behaviour verdicts, but units 1 and 9
do not have unconditional four-axis parity.

## Gaps

- **0 missing widgets/dialogs/menu items/actions/signals.** Re-confirmed on
  this round's re-check of all 11 units against source.
- **1 real reliability gap, newly found this round**: the search-provider
  D-Bus driver (Unit 10) fails roughly 1 run in 3 on a register-vs-own-name
  race. Not a missing feature — an unverified-under-load feature currently
  reported as settled.
- **12 translation-only extra msgids**, unchanged from the prior round; see
  `translation-parity.md`.
