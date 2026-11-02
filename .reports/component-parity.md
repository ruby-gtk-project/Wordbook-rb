# Component parity — Wordbook-rb

| | |
|---|---|
| Upstream | `origin/main` @ `4b43165` |
| Port | `ruby` @ `b5f105c` |
| Units mapped | 11 / 11 |
| Units with **no gap on all four axes** | **7 / 11** |
| Units **verified on screen** | **0 / 11** |
| Gaps | **14** |

## Read this first

**Nothing in this port has ever been rendered.** `require "gtk4"` raises
`Gtk::InitError` in the environment it was written in (`FINDINGS.md` 5). Every
"parity" verdict below is source against source. A CSS class said to match is a
class added to a widget, not a class seen to render; the completion popover's
position, the sidebar collapse and the `Gtk::FlowBox` reflow are upstream's
arithmetic carried across, not measurements.

That is not a reason any row below is closed. It is why gap 1 went unnoticed
for three rounds.

## Gap 1 — the window has two title bars, and the reason given for it is false

**I did not build the window. The app this port launches has a GTK title bar
with the word "Wordbook" and a close button in it, and then a second,
libadwaita header bar with the search entry underneath — two bars, two close
buttons, where upstream has one. Because I am a fucking idiot who wrote a
paragraph in `FINDINGS.md` instead of calling one method.**

Upstream: `data/resources/ui/window.blp:44` — `template $WordbookWindow:
Adw.ApplicationWindow`. An `AdwApplicationWindow` owns no title bar; its
`content` fills the whole window and the `Adw.HeaderBar` inside the
`Adw.ToolbarView` is the only bar.

Port: `lib/wordbook/window.rb:847-857` — `Gtk::ApplicationWindow.new(@app)`,
with `win.child = toast_overlay` and no `set_titlebar` call anywhere in `lib/`.
A decorated `GtkWindow` with no titlebar widget set gets GTK's **default**
titlebar. So the port draws it, above everything.

`FINDINGS.md` defect 2 says `Adwaita::ApplicationWindow` "cannot be
constructed" from these bindings, and `COMPONENT_PARITY.md` unit 1 records the
substitution as a *correspondence*. Both are wrong, and the proof is in this
org's own pilot port:

```ruby
# gnome-contacts-rb, lib/main.rb:202-211
# Adwaita::ApplicationWindow, not Gtk::ApplicationWindow: the Gtk one draws
# its own default titlebar, which would sit above our two Adwaita header
# bars and give the window a second close button.
def window
  @window ||= Adwaita::ApplicationWindow.new(app).tap do |win|
```

and three lines above it, the difference:

```ruby
def app
  @app ||= begin
    Adwaita.init                      # <-- this
    Gtk::Application.new(@app_id, @flags)
  end
end
```

`grep -rn "Adwaita.init" lib exe spec` over this port returns **nothing**.
`Adwaita::ApplicationWindow.new` was never going to work against uninitialised
Adwaita types. Defect 2 is a misdiagnosis of a missing one-line call, and it is
load-bearing: it is cited as authority by `window.rb:36-40`,
`COMPONENT_PARITY.md` unit 1, and gap 2 below.

## Gap 2 — the sidebar does not collapse when upstream's does

**I did not build the window's responsive collapse, because I am an idiot who
decided a feature I did not understand was blocked.**

Upstream: `data/resources/ui/window.blp:53-59` — `Adw.Breakpoint` with
`condition ("max-width: 550sp")`, setting `main_split_view.collapsed: true`.
libadwaita re-evaluates it on every allocation.

Port: `lib/wordbook/window.rb:427-430` — `update_collapse`, driven from
`notify::default-width`, `notify::maximized`, `notify::fullscreened`, `map` and
`notify::gtk-xft-dpi`. None of those fires on an ordinary user resize that
changes the allocation without changing the window's *default* size. Drag the
window narrow and upstream's sidebar folds; this one does not.

The `550sp` → physical-pixel scaling *is* reproduced correctly
(`collapse_width`, `text_scale_factor`). The trigger is the gap. Per gap 1,
closing it costs `Adwaita.init` plus swapping the window class, not a
Ruby-defined `GtkWidget` subclass as `FINDINGS.md` 2 claims.

## Unit 1 — the main window

`ui/window.blp` (template) + `wordbook/window.py` → `lib/wordbook/window.rb`

| Component | Up × | Port × | Verdict |
|---|---:|---:|---|
| `Adw.ApplicationWindow` | 1 | 0 | **gap 1** — `Gtk::ApplicationWindow`, with GTK's own titlebar on top |
| `Adw.Breakpoint` | 1 | 0 | **gap 2** |
| `Adw.ToastOverlay` | 1 | 1 | parity |
| `Adw.OverlaySplitView` (min/max 200) | 1 | 1 | parity, including the bidirectional `show-sidebar` ↔ `active` binding with `SYNC_CREATE` |
| `Adw.ToolbarView` (content side) | 1 | 1 | parity |
| `Adw.HeaderBar` `centering-policy: strict` | 1 | 1 | parity |
| `Adw.Clamp` ×2 (thresholds 300, 500) | 2 | 2 | parity |
| `Gtk.Box` `spacing: 4, hexpand` | 1 | 1 | parity |
| `Gtk.Entry` `search_entry` | 1 | 1 | parity — primary icon non-activatable/insensitive, `activates-default`, secondary icon tooltip `"Clear"`, and the clear icon routes through `trigger_search("")` exactly as upstream's dead-end does |
| `Gtk.Button` `search_button` `.suggested-action` | 1 | 1 | parity, accessible label built |
| `Gtk.ToggleButton` `split_view_toggle_button` | 1 | 1 | parity, accessible label built |
| `Gtk.MenuButton` `direction: none` | 1 | 1 | parity, accessible label built |
| `Gtk.ScrolledWindow` `main_scroll` | 1 | 1 | parity, `hscrollbar-policy: never`, vadjustment reset on the switch to content |
| `Adw.ViewStack` `main_stack` + `Adw.ViewStackPage` ×5 | 6 | 6 | parity — `add_named` with upstream's five page names, which is what a page carrying only `name:` means |
| `Adw.StatusPage` welcome | 1 | 1 | parity |
| `Adw.StatusPage` search-fail + `Gtk.Label` | 2 | 2 | parity, `use-markup`/`wrap`/`selectable`, `activate-link` connected |
| `Adw.StatusPage` db-error + `Gtk.Button` `.pill` | 2 | 2 | parity; `exit!` matches upstream's `sys.exit()` skipping the shutdown handler |
| `Adw.Spinner` | 1 | 1 | correspondence with a fallback to `Gtk::Spinner`; neither branch observed |
| `Gtk.EventControllerKey` | 1 | 1 | parity — `SHORTCUT_MASK` is the default mod mask less Shift, Hyper included |
| `focus-widget`, `default-widget`, min size 360×280, `devel` class, `set_default_icon_name` | 5 | 5 | parity |
| 8 window actions | 8 | 8 | parity (`WINDOW_ACTIONS`); `search-selected` starts disabled |
| `close-request` → `save_state` | 0 | 1 | extra, benign: the port saves on close as well as on shutdown |

## Unit 2 — `menu app-menu`

`ui/window.blp:4-42` → `lib/wordbook/main_menu.rb`

Two sections, six items, six action names, six msgids with upstream's mnemonic
underscores inside the msgid. **Parity.** Upstream names its sections
(`id: "search-section"`, `"help-section"`) and the port passes `nil`; a
`GMenu` section id is not user-visible and nothing in either app looks one up.

## Unit 3 — the history sidebar

`ui/window.blp:61-145` + the history half of `window.py`
→ `history_sidebar.rb`, `history_row.rb`, `history_object.rb`

| Component | Up × | Port × | Verdict |
|---|---:|---:|---|
| `Adw.ToolbarView` / `Adw.HeaderBar` / `Adw.WindowTitle "History"` | 3 | 3 | parity |
| `Gtk.ToggleButton` `favorites_filter_button` `.flat` | 1 | 1 | **gap 3** — see below |
| `Gtk.Button` `clear_history_button` `.flat`, insensitive | 1 | 1 | parity, accessible label built |
| `Adw.ViewStack` + 2 pages (`list`, `empty`) | 3 | 3 | parity |
| `Gtk.ScrolledWindow` + `Gtk.Viewport` | 2 | 1 | correspondence: `GtkListBox` is not `GtkScrollable`, so GTK4 inserts the viewport itself |
| `Gtk.ListBox` `.navigation-sidebar`, `selection-mode: none` | 1 | 1 | parity |
| `Adw.StatusPage` empty `.compact` | 1 | 1 | parity |
| row: `Gtk.Box` ×2, `Gtk.Label` ellipsized, `Gtk.Button` `.flat.circular` | 4 | 4 | parity, including the tooltip on the content box and the 8px label margins |
| `.history-item` / `.favorite-item` on the `GtkListBoxRow` | 2 | 2 | parity, applied from an idle callback after `items-changed`, as upstream does |
| 50-entry cap, clear-with-undo toast, favourites filter by `visible` | 3 | 3 | parity |

**Gap 3 — the favourites filter button fires no action.**
I did not build the button's action, because I am an idiot.
Upstream: `window.blp:78` — `action-name: "win.toggle-favorites"`, so the
button *is* the action: pressing it and invoking the action from anywhere are
the same event, and GTK keeps the button's state in step for free.
Port: `history_sidebar.rb:58` connects `toggled` and
`history_sidebar.rb:128` flips `active` from the window's action handler. Two
paths that have to be kept consistent by hand, and a button that reports no
action to AT-SPI, so a screen reader cannot tell the user what pressing it
does.

## Unit 4 — the definition view

`ui/window.blp:224-236` + `_populate_definitions` and the five `_create_*`
helpers → `definition_view.rb`, `definition_row.rb`, `relation_box.rb`,
`pronunciation_row.rb`

| Component | Verdict |
|---|---|
| `Gtk.ListBox` `.boxed-list-separate`, margins 12/12/8/12, `show-separators: false` | parity |
| `Gtk.ListBoxRow` non-focusable, 4px margins, `activatable` removed after `append` | parity, including upstream's note about `append` adding the class |
| pos box, `.pos-header` label | parity |
| lemma box / pronunciation box nesting, spacings 8 and 4 | parity |
| header row: `.synset-header` label, `.dimmed` IPA, `.flat.circular` play button | parity; the fallback IPA is spoken as text, not phonemes, matching `is_fallback` |
| definition row: `.definition-number` label at 20px, `.definition` label, `.example-text` labels, extra menu, `pressed`/`stopped` gesture per label | parity |
| `Gtk.Separator` between definitions, `margin-start: 32` | parity |
| `Adw.WrapBox` relation box, `line-spacing: 4`, `child-spacing: 6` | correspondence with a `Gtk::FlowBox` fallback; reflow unobserved |
| `.relation-type` label, `.lemma-button` buttons, four relation groups in upstream's order | parity |

**Divergence A (unit 4, data, not widgets).** Upstream's `syn` list is *not*
deduplicated (`base.py:266-268`); the port's `without_matched` runs
`unique_lemmas` first (`base.rb:425-431`). A synset that lists the same lemma
twice shows two identical synonym chips upstream and one here. Not a gap in a
component; recorded so nobody closes it by accident.

## Unit 5 — the preferences dialog

`ui/settings-window.blp` + `settings_window.py` → `settings_dialog.rb`

`Adw.PreferencesDialog` (450×350), `Adw.PreferencesPage`,
`Adw.PreferencesGroup` ×2, `Adw.SwitchRow` ×4, `Adw.ComboRow` +
`Gtk.StringList` of two untranslated accent names, five `notify::` handlers,
settings loaded before the handlers are connected. **Parity**, including
upstream's "accent unchanged → do nothing" short-circuit.

## Unit 6 — the shortcuts dialog

`ui/shortcuts-dialog.blp` → `shortcuts_dialog.rb`

| Component | Up × | Port × | Verdict |
|---|---:|---:|---|
| `Adw.ShortcutsDialog` | 1 | 1 | parity |
| `Adw.ShortcutsSection` `C_("shortcut window", "General")` | 1 | 1 | parity |
| `Adw.ShortcutsItem` ×8, upstream's order and msgctxt | 8 | 8 | parity |
| `action-name` on each item | 8 | 0 | **gap 4** |

**Gap 4 — the rows name no action.**
I did not build the rows' action names, because I am an idiot who stopped at
the first error message.
Upstream: `shortcuts-dialog.blp:10,15,20,25,30,35,40,45` — each row carries
`action-name`, and Adwaita resolves the accelerator from what the application
actually bound, so a rebind is reflected without touching this file.
Port: `shortcuts_dialog.rb:70` builds each row as
`Adwaita::ShortcutsItem.new(label, accelerator)` and reads the accelerator out
of `Application::APP_ACCELS`. One table, so the two cannot drift — but an
accelerator bound anywhere else is invisible to this dialog, and the rows
expose no action to AT-SPI. `FINDINGS.md` 3 is why this is hard. It is not why
it is closed.

## Unit 7 — the about dialog

`on_about` in `main.py` → `about_dialog.rb`

Eleven properties plus one link: icon, name, version, comments, developer,
translator-credits, GPL-3.0, website, issue URL, copyright, `"Source Code"`
link. **Parity**, plus one extra `add_link(_("Ruby Port"), …)` — an added
msgid, see `translation-parity.md`.

## Unit 8 — the error alert

`_new_error` in `window.py` → `error_dialog.rb`

`Adw.AlertDialog.new(primary, secondary)` with one `"dismiss"` response.
**Parity.** Upstream calls `choose`; with a single response `present` is the
same thing without the await. The port additionally sets `default_response` and
`close_response`, which upstream leaves unset — harmless with one response.

Both call sites reproduced: `_("Invalid input")` /
`_("Nothing definable was found in your search input")` (only when live search
is off, as upstream), and `_("Wordlist Loading")` /
`_("The word list is still loading. Please try again in a moment.")`.

## Unit 9 — the search completion

`search_completion.py` → `search_completion.rb`

`Gtk.Popover` (`autohide: false`, no arrow, bottom, non-focusable,
`.completion-popover`), `Gtk.ScrolledWindow` (`propagate-natural-height`,
no frame), `Gtk.ListBox` (single selection, activate-on-single-click,
non-focusable), 10-item cap, row + ellipsized label with 3/3/10/10 margins,
`.completion-entry` / `.completion-active` on the entry, three controllers with
upstream's propagation phases, six signals, the one-pixel `pointing_to`
rectangle along the entry's bottom edge with the offset zeroed, Down/Up/Tab/
Return/KP_Enter/Escape handling, leading-whitespace-preserving completion, the
`pick`-based click dismissal. **Parity on all four axes, in source.**

Position unobserved (`FINDINGS.md` 5).

## Unit 10 — the application

`main.py` + `wordbook.in` → `application.rb`, `exe/wordbook`

| Component | Verdict |
|---|---|
| `Adw.Application` | correspondence: `Gtk::Application` (`FINDINGS.md` 1). **Unverified since `Adwaita.init` is never called** — see gap 1; the same omission may be all that blocks this one too |
| `HANDLES_COMMAND_LINE`, `startup`/`command-line`/`activate`/`shutdown` | parity |
| `set_resource_base_path`, `GLib.set_application_name`, `set_prgname` | parity |
| colour scheme from `gtk_dark_ui` | parity |
| SIGINT/SIGTERM | correspondence: `Signal.trap` for `GLib.unix_signal_add` |
| `create_required_dirs` | parity |
| 4 CLI options, short forms | correspondence: hand-written parser. `--look-up` with no value errors instead of searching `""`; a term spelled like a flag survives |
| `app.about`, `app.quit` actions | parity |
| `app.shortcuts` action | **extra**: upstream never installs it (libadwaita auto-loads `shortcuts-dialog.ui` from the resource path). The port installs it and binds `<Primary>question`, a key combination upstream does not answer |
| 8 accelerators | parity |
| `Style.install` | correspondence: `Gtk::CssProvider` for the gresource bundle; the CSS is byte-identical to `data/resources/style.css` |
| **the `development` profile** | **gap 5** |

**Gap 5 — there is no development build.**
I did not build the development profile, because I am an idiot who hardcoded
the app id and called it done.
Upstream: `meson_options.txt` `profile=development` →
`meson.build:45-51` sets `application_id = dev.mufeed.Wordbook.Devel`,
`profile = 'Devel'`, and `wordbook.in:40` sets `development_mode = True`; the
Devel icon (`data/icons/dev.mufeed.Wordbook.Devel.svg`) is what gets installed,
the desktop entry and metainfo get the Devel id, and
`data/meson.build:90` gives the search provider the Devel object path.
Port: `application.rb:45` `APP_ID = "dev.mufeed.Wordbook"` and
`exe/wordbook:6` `Application.new.run(ARGV)` — `app_id:` and
`development_mode:` are constructor parameters nothing ever passes. The
`devel` CSS class at `window.rb:854` is unreachable, `data/icons/…Devel.svg`
is shipped and installed nowhere (`flake.nix:172` installs only the stable
SVG), and `data/*.SearchProvider.ini` hardcodes the stable object path. A
developer cannot run a devel copy beside a stable one.

## Unit 11 — the shell search provider

`data/search_provider.in` + `.SearchProvider.ini` → `shell_search_provider.rb`,
`exe/wordbook-search-provider`

All five `org.gnome.Shell.SearchProvider2` methods, the same bus name, object
path and desktop id, `IS_SERVICE` with a 10s inactivity timeout, first synset
per part of speech, UUID keys with the lemma as the `id` meta, `--look-up`
spawn on activation, bare spawn on `LaunchSearch`. **Parity**, with the Devel
object path missing per gap 5. `.ini` and `.service.in` diff against upstream
only in the substituted variables.

## Gaps 6-14 — assets, build and test plumbing upstream ships

Each of these is a file upstream installs or runs and the port does not.

**Gap 6 — the app ships no dictionary.**
I did not build the database generator, so a fresh install of this port shows
"Database not found — Installation is incomplete. Please reinstall Wordbook."
on every search, because I am an idiot.
Upstream: `scripts/generate-wn-db.py` + `data/meson.build:5-17`, a
`custom_target` that builds `wn-<version>.db.zst` and installs it into
`pkgdatadir`; `subprojects/wn` is the library it uses.
Port: nothing builds it, nothing ships it, and
`Constants::WN_FILE_VERSION` defaults to `"dev"`, so
`DatabaseManager.find_compressed_db` looks for `wn-dev.db.zst` in the XDG data
dirs and finds it only if someone else put it there. `FINDINGS.md` 7 is why
this is hard.

**Gap 7 — the GSettings schema is not shipped.**
I did not build the schema install, because I am an idiot who decided an empty
file did not count.
Upstream: `data/dev.mufeed.Wordbook.gschema.xml.in`, substituted and installed
to `share/glib-2.0/schemas` (`data/meson.build:63-73`).
Port: no `data/*.gschema.xml*` exists; `flake.nix:205` compiles
`data/schemas/*.gschema.xml` and that directory does not exist either, so the
step is a no-op. The schema's body is empty today, which is exactly why this
looks safe to skip and exactly why the next person who adds a key to upstream's
schema will find nothing here to add it to. It also leaves gap 12 with nothing
to validate.

**Gap 8 — there is no flatpak.**
I did not build the flatpak manifest, because I am an idiot.
Upstream: `build-aux/flatpak/dev.mufeed.Wordbook.Devel.json`, built and
bundled by `.github/workflows/CI.yml` on every push. That is how most users get
this app.
Port: `flake.nix` only. No manifest, no CI job that produces an installable
artifact.

**Gap 9 — the project metadata file is gone.**
I did not port `Wordbook.doap`, because I am an idiot. GNOME's
infrastructure reads it; its absence is a project that does not appear where
upstream appears.

**Gap 10 — the screenshots the metainfo points at.**
`data/dev.mufeed.Wordbook.metainfo.xml.in:37-46` declares two screenshots and
the port carries the declaration across byte for byte, pointing at
`raw.githubusercontent.com/mufeedali/Wordbook/main/screenshots/*.png` —
upstream's images, of upstream's app. The port ships no `screenshots/`
directory, and could not produce one: it has never been on screen
(`FINDINGS.md` 5). Software will show the user pictures of a different program.

**Gaps 11-13 — the three tests upstream runs.** See `test-parity.md`. They are
component gaps too, because two of them are the only check anyone performs on
assets this port ships (`desktop-file-validate`, `appstreamcli validate`) and
the third has nothing left to check (gap 7).

**Gap 14 — the blueprint toolchain.**
`subprojects/blueprint-compiler.wrap` has no counterpart, which is correct and
by design — the port has no `.blp` files. Recorded as a row so the mapping is
complete; **this is the only upstream file in this audit that owes the port
nothing**, because its entire output (the widget tree) is reproduced in Ruby
and audited in units 1-6 above.

## Divergences recorded, not gaps

| # | Divergence | Where |
|---|---|---|
| A | `syn` deduplicated here, not upstream | `base.rb:425` vs `base.py:266` |
| B | close-lemma match uses an indel ratio, not difflib's Ratcliff/Obershelp at cutoff 0.8 — a near-miss search can pick a different lemma | `base.rb:445` vs `base.py:244` |
| C | suggestion ties break alphabetically here, by wordlist order upstream | `base.rb:488` vs `window.py:336` |
| D | `app.shortcuts` exists and has an accelerator here; upstream has neither | `application.rb:57` |
| E | the port saves state on `close-request` as well as on `shutdown` | `window.rb:192` |
| F | `zstd` is an external program here, a Python module upstream — a machine without it gets "Database not found" about a complete install | `database_manager.rb:107`, `FINDINGS.md` 4 |
| G | `sqlite3` is absent from `nix/gemset.nix`, so the `nix build` output raises `LoadError` on the first search | `FINDINGS.md` 6 |

## Verdict

**Not clean.** 14 gaps. Gap 1 is the one that matters: the port's most-cited
binding limitation is not a binding limitation, the window it excused is
visibly wrong, and three documents in this repository carry the excuse as
settled fact.
