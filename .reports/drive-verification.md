# Drive verification — Wordbook-rb

| | |
|---|---|
| Port | `ruby` |
| Harness | `test/drive_wordbook.rb` + `test/gtk_driver.rb` (the shape of `tally-rb`'s) |
| Fixture | `test/wn_fixture.rb` — a small WordNet database in `wn`'s schema |
| Command | `nix develop --command xvfb-run -a ruby test/drive_wordbook.rb` |
| Result | **198 of 198 checks passed — `DRIVE OK`** |
| Screenshots | 19 PNGs in `tmp/shots`, looked at |
| Spec suite | `118 examples, 0 failures` |

## What is driven

Every file in `lib/` is exercised: the application and its actions and
accelerators, the window and its five pages, the definition view, definition
rows, pronunciation rows and relation chips with real search results, the
history sidebar with its rows, favourites, filter, clear-with-undo toast and
empty state, the completion popover and its four keys, the quick-search key
controller, all four dialogs (preferences, about, shortcuts, the invalid-input
alert), the main menu, the responsive breakpoint, the stylesheet, the
settings round trip through the JSON file, espeak-ng, the database manager and
the GNOME Shell search provider.

## Two things the run found that reading the source had not

**The clipboard handlers rescued a class the bindings never raise.** Upstream
catches `GLib.Error`; these bindings raise `Gio::IOError::NotFound`, which
descends from `Gio::Error` and not from `GLib::Error`. An empty primary
selection therefore raised out of a signal handler and ended the process. The
driver died silently mid-run until it was fixed. `FINDINGS.md`, defect 11.

**`Gtk::Widget#activate_action` activates nothing in these bindings.** It
returns the widget and has no effect. The previous driver checked seven window
actions with it and asserted only that it did not raise, so seven green checks
covered nothing. Actions are now activated through the `Gio::SimpleAction` the
window registered, and each one is checked for what it changed.
`FINDINGS.md`, defect 12.

## What this run still does not settle

- the screenshots have not been put beside upstream's and compared;
- the packaged app (`nix build`) still has no `sqlite3` in its bundle
  (`FINDINGS.md`, defect 6), so what is proven here is the code, not the
  package;
- the port still ships no WordNet archive (`FINDINGS.md`, defect 7); the
  database the driver searches is the fixture, not upstream's lexicon;
- keyboard *accelerators* are verified through the accelerator table and the
  keys the shortcuts dialog resolves from it, not by synthesising key events:
  GTK4 exposes no way to inject one. The quick-search key handler is driven
  by emitting `key-pressed` on the window's own `Gtk::EventControllerKey`.
