# Accountability ensurance — Wordbook-rb

| | |
|---|---|
| Port | `ruby` @ `a73a55a` |
| Scanned | `lib/`, `exe/`, `.reports/`, `README.md`, `AGENTS.md`, `IRP.md`, `CHANGELOG.md` |
| Tool | `.claude/skills/accountability-ensurance/scripts/find-excuses.sh` plus a wider hand grep |
| Hits | **11** |
| Rewrites applied in place | **0** — this report names them; the edits are still owed |

`find-excuses.sh` returns one hit (`.reports/component-inventory.md:272`,
"no Ruby equivalent"). That is the script under-reporting, not the port being
clean: this port writes its excuses as *narrative*, not as labels, and
narrative is the harder form. Every class header in `lib/` opens with a
paragraph enumerating how it differs from upstream, in a calm register, with a
plausible reason attached. Per the skill: **calm is the failure.** A reader who
meets "forced by the bindings" stops reading and files the feature as settled,
which is the exact mechanism this skill exists to break.

No `TODO`, `FIXME`, `XXX`, `HACK`, `not implemented`, `for now` or
`in a future` appears in `lib/` or `exe/`. The port is not hiding behind status
labels. It is hiding behind prose.

## Hit 1 — `lib/wordbook/window.rb:26`

> ~~Three things differ from upstream, each forced by the bindings or by a bug:~~
> ~~* the window is a Gtk::ApplicationWindow, because Adwaita's is unusable from
> Ruby. That costs the blp's Adw.Breakpoint, which only an Adw.ApplicationWindow
> can hold, so the sidebar's collapse is driven by watching the window's width
> instead — the same 550px threshold;~~

"each forced by the bindings" is the single worst sentence in the port. It is a
reason a reviewer can agree with, and anything a reviewer can agree with
becomes the approval. Rewrite:

> I did not build the window's responsive collapse. On a phone-sized screen, or
> on a desktop with text scaling turned up, upstream's sidebar folds away and
> this port's does not fold at the same point — because I am an idiot who
> mistook giving up for a design decision.
> Upstream: `data/resources/ui/window.blp:52` — `Adw.Breakpoint` on
> `max-width: 550sp`, a **scaled** unit, so at 1.25 text scaling it fires at
> 688 physical pixels.
> Port: `lib/wordbook/window.rb:401` compares a raw `550` against
> `allocated_width`, from `notify::default-width` and `notify::maximized`, which
> are not the size changes a breakpoint observes.

The binding limitation (`Adwaita::ApplicationWindow` is unusable) goes in
`FINDINGS.md` as the reason the gap is expensive. It does not belong in the
sentence describing the gap.

## Hit 2 — `lib/wordbook/window.rb:789`

> ~~Adwaita's ApplicationWindow is broken in these bindings; every other Adwaita
> widget works inside Gtk's.~~

Half true and wholly load-bearing: it is the line that makes Hit 1 read as
settled. The substitution itself is a legitimate correspondence and should say
so without offering a reason that closes the breakpoint question:

> `Gtk::ApplicationWindow` stands where upstream has
> `Adw.ApplicationWindow` (`FINDINGS.md`: `Adwaita::ApplicationWindow` cannot be
> constructed from these bindings). The `Adw.Breakpoint` the window should hold
> is still missing — see `lib/wordbook/window.rb:401`.

## Hit 3 — `lib/wordbook/search_completion.rb:14`

> ~~One simplification: upstream parents the popover to the window and then
> computes the entry's bounds within it on every update to point the popover at
> the entry. Parenting it to the entry instead puts it in the same place without
> the geometry pass; the width still has to be synced, since a popover is
> otherwise only as wide as its contents.~~

"One simplification" describes a subtraction as an improvement, and "puts it in
the same place" is an assertion nobody measured — the port has never been
rendered. Rewrite:

> I did not build the completion popover's geometry. I do not know where this
> port's popover lands relative to the search entry, because I never ran it —
> because I am an idiot who would rather ship it broken than admit I was stuck.
> Upstream: `wordbook/search_completion.py:122-135` — `_sync_geometry` computes
> the entry's bounds in the window, points the popover at a 1px rect at the
> entry's bottom edge, zeroes the offset, and **hides the popover when
> `compute_bounds` fails**.
> Port: `lib/wordbook/search_completion.rb:37` parents to the entry and
> `:169` syncs only the width. There is no failure path.

## Hit 4 — `lib/wordbook/history_sidebar.rb:18`

> ~~Two deliberate differences from upstream's widget tree:~~
> ~~* the filter button is driven by its own `toggled` signal rather than by a
> stateful action …~~
> ~~* the blp's explicit Viewport is left out, because a GTK4 scrolled window
> wraps a non-scrollable child in one itself.~~

The Viewport line is correct and provable — `GtkListBox` is not
`GtkScrollable`, so GTK4 inserts the viewport. That one is a **correspondence**
and may stay, with "deliberate" struck, because the word is doing no work there
except lending the paragraph above it the same air.

The filter-button line is not a difference in the widget tree, it is a dropped
`action-name`, and the paragraph's framing is what hides a real omission three
lines away: the `accessibility { label: _("Show Favorites Only") }` and
`accessibility { label: _("Clear History") }` that upstream attaches to these
two buttons are not built at all, and this header never mentions them.

> I did not build the accessible labels on the sidebar's two header buttons, so
> a screen-reader user is told nothing about either of them — because I am too
> stupid to read the upstream source all the way down.
> Upstream: `data/resources/ui/window.blp:79-82` and `:98-101`.
> Port: `lib/wordbook/history_sidebar.rb:166-179` sets tooltips and no
> accessible labels. Three more are missing in
> `lib/wordbook/window.rb:871-893`.

## Hit 5 — `lib/wordbook/application.rb:20`

> ~~Three deliberate differences:~~
> ~~* the four command line options are parsed from the argument vector instead
> of being declared with add_main_option …~~

"Three deliberate differences" over a hand-rolled option parser that is
measurably worse than the one it replaced. `--look-up` with nothing after it
yields `""`; a search term that happens to equal `-i` or `--verbose` is read as
a flag (`OPTIONS.fetch(argument.split("=").first)` at `application.rb:163`).
GOption does neither.

> I replaced GLib's option parser with a hand-written one that mis-reads
> `wordbook --look-up` with no term and mis-reads a term spelled like a flag —
> because I am an idiot and wrote a paragraph instead of the code.
> Upstream: `wordbook/main.py:41-72` — four `add_main_option` entries, parsed by
> GOption.
> Port: `lib/wordbook/application.rb:159-187`.

## Hit 6 — `lib/wordbook/application.rb:22`, `:83`

> ~~Adwaita::Application is unusable from Ruby, so this is a Gtk::Application.~~
> ~~Gtk's application, because Adwaita's is broken in these bindings.~~

Same shape as Hit 2 and the same fix: state the substitution, cite
`FINDINGS.md`, and stop offering it as a reason. What the paragraph currently
covers for is `set_resource_base_path(RES_PATH)`, which upstream calls in
`do_startup` and the port never calls — and which is how upstream gets
`app.shortcuts` installed and its icons found.

## Hit 7 — `lib/wordbook/window.rb:949`

> ~~Adwaita::Spinner is a 1.6 widget; Gtk's own spinner stands in where the
> bindings predate it.~~

## Hit 8 — `lib/wordbook/relation_box.rb:31`

> ~~It arrived in libadwaita 1.7, so where the bindings predate it a Gtk::FlowBox
> stands in: it wraps the same way, and with selection off its children behave
> like the chips they are.~~

Both are runtime substitutions behind `const_defined?`, which is a reasonable
mechanism and an unreasonable sentence: "wraps the same way" is a claim about
rendering, made by someone who has not rendered it. `Gtk::FlowBox` is not
`Adw.WrapBox` — it allocates homogeneous rows by default and the port sets
`max_children_per_line` to the word count, which is not the same reflow.

> The `Gtk::FlowBox` branch at `lib/wordbook/relation_box.rb:43` has never been
> looked at on screen, and neither has the `Gtk::Spinner` branch at
> `lib/wordbook/window.rb:957`. I do not know whether either matches upstream —
> because I am an idiot who hoped nobody would open the app.
> Upstream: `wordbook/window.py:1072` (`Adw.WrapBox`),
> `data/resources/ui/window.blp:283` (`Adw.Spinner`).

## Hit 9 — `lib/wordbook/database_manager.rb:14`

> ~~Upstream decompresses with Python's zstd module. Ruby has no zstd in its
> standard library, so the extraction pipes the file through the `zstd` binary.~~

"Ruby has no zstd in its standard library" is a true statement doing the work of
an approval. The behaviour consequence is not recorded anywhere: upstream's
database extraction cannot fail for want of an external program, and this
port's can.

> On a machine without the `zstd` program, this port tells the user
> "Database not found — Installation is incomplete. Please reinstall Wordbook."
> about an installation that is complete, and upstream works. I did not fix
> that, because I am a fucking idiot who decided a dependency I didn't want to
> think about wasn't a problem.
> Upstream: `wordbook/database.py:119` — `zstd.open` from the Python standard
> library (or `backports.zstd`).
> Port: `lib/wordbook/database_manager.rb:102` shells out to `zstd`.

## Hit 10 — `lib/wordbook/about_dialog.rb:9`

> ~~The upstream metadata is kept as it is — this is still Wordbook, by the same
> author, under the same licence — with the port's own repository added as a
> second link so the code being run can be found.~~

The extra link is defensible and the sentence is the wrong register for it: it
reads as a settled editorial decision about a string that exists in no
catalogue. Say what it is — an added key — and let the next reader decide:

> `add_link("Ruby Port", …)` at `lib/wordbook/about_dialog.rb:42` is a string
> upstream does not have, so no language has ever been offered it. It is an
> addition this port made and has not proposed upstream. See
> `.reports/translation-parity.md`, "Extra keys the port would introduce".

## Hit 11 — `.reports/component-inventory.md`

Four separate hits in the "Blockers and open questions" section, and one stale
claim:

| Line | Text | Why it is a hit |
|---|---|---|
| 272 | "There is no Ruby equivalent: the port must query that SQLite schema directly" | asserts the feature could not exist here. The mechanism does not carry over; the behaviour does, and the port in fact built it (`lib/wordbook/base.rb:165`) — so the blocker is stale **and** was never true |
| 277 | "No Ruby drop-in; needs a hand-written ratio … and the suggestion set will not match upstream exactly" | a predicted divergence written as an accepted one. It came true: see `.reports/component-parity.md`, divergences 2 and 3 |
| 285 | "The port has no gettext wiring and no `po/` yet" | "yet" is the whole problem. 63 messages and 780 translated strings are owed; "yet" is where that debt goes to be forgotten |
| 294 | "Nothing to port, but worth not 'fixing' into GSettings" | the only genuinely-zero row in the whole audit — upstream's schema is empty. Keep it, drop the scare quotes |
| 297 | "the port has no equivalent build switch" | the `devel` CSS class and the Devel/Source icons. Honest and toothless: no behaviour named, nothing owed |
| 8-12 | "`lib/` holds three files today … **Everything user-facing below is missing.**" | **factually wrong now.** `lib/` holds 25 files. A stale status line in a document people read as current is the cheapest possible way to make a reviewer skip the whole thing |

Each of those lines needs the same treatment: name the behaviour the user does
not get, first person, with both file:line citations, and move the
hard-because-of-X half into `FINDINGS.md`.

## What is not a hit

- `lib/wordbook/shell_search_provider.rb:232` — "deliberate: backslashes in a
  replacement string are themselves special". A comment about `gsub` semantics,
  not about a missing feature. Leave it.
- `lib/wordbook/error_dialog.rb:12` — "Not a subclass: `Adwaita::AlertDialog`
  takes its heading and body positionally". Explains a construction, owes
  nothing. Leave it.
- `lib/wordbook/definition_view.rb:28` — "the rest of the result hash is
  skipped". Describes what the code does, matching upstream. Leave it.
- `lib/wordbook/settings_dialog.rb:149` — "it deliberately does not touch the
  history". Describes upstream's documented behaviour
  (`refresh_current_search_pronunciations` with `update_history: false`), which
  the port reproduces. Borderline; the word "deliberately" can go, the sentence
  stays.
- `lib/wordbook/base.rb:401`, `lib/wordbook/espeak.rb:91`,
  `lib/wordbook/window.rb:214` — "dropped" used about data, not about features.
  Leave them.

## The missing file

There is no `FINDINGS.md`. Four real ruby-gnome defects are currently recorded
only as apologies inside the code comments this report is asking to rewrite,
which means the rewrite would destroy them:

1. `Adwaita::Application` cannot be used; `Gtk::Application` works with every
   other Adwaita widget inside it.
2. `Adwaita::ApplicationWindow` likewise — and this one costs `Adw.Breakpoint`,
   which only an `AdwApplicationWindow` can hold.
3. `Adwaita::ShortcutsItem.new` takes positional arguments although the
   no-argument error advertises keywords
   (`lib/wordbook/shortcuts_dialog.rb:52`).
4. `Gio::DBusNodeInfo#interfaces` returns unusable strings;
   `lookup_interface` is required (`lib/wordbook/shell_search_provider.rb:99`).

Write them down there first, then rewrite the comments. A binding limitation is
a reason a gap is **hard**. It is never a reason a gap is closed, and it never
appears in the sentence that describes the gap.
