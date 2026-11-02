# frozen_string_literal: true

# Drives the whole app headlessly: builds the real window, waits for the real
# database setup, searches real terms, opens every dialog and menu, fires every
# action and every keyboard path, hits the empty and error states, and
# screenshots each one.
#
# Why this file exists: a GTK app that loads is not a GTK app that works.
# `ruby -c` passes on code that builds an empty window, and this port had
# already been reported "verified" on static analysis while its startup
# aborted on the accessible labels (FINDINGS.md, defect 10) — the source had
# read as correct for a whole round.
#
# Run it from the repository root:
#
#   nix develop --command xvfb-run -a ruby test/drive_wordbook.rb
#
# GTK4 here has no offscreen backend (gtk_init fails outright with no display),
# so xvfb-run is not optional on this machine; the dev shell's banner names it.
#
# The search half needs a WordNet database. Upstream ships a zstd archive its
# meson build generates, and nothing in this checkout has one, so the window
# stops on "Database not found" and every component behind it — the definition
# view, the pronunciation rows, the relation chips, the completion popover, the
# history — is code no run has ever entered. test/wn_fixture.rb writes a tiny
# database in the same schema, which is what lets the steps below drive the
# content page for real rather than asserting around it. The "Database not
# found" page is still checked, and so is the condition that produces it.
#
# The specs under spec/ cover the display-free half (118 examples). What is
# driven here is what needs a widget.

require "fileutils"
require "json"
require "tmpdir"

# Scratch directories, so a run never reads or writes the real ones. Both are
# set before anything in lib/ is loaded: Utils computes CONFIG_DIR and DATA_DIR
# at load time.
ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("wordbook-drive-config")
ENV["XDG_DATA_HOME"] = Dir.mktmpdir("wordbook-drive-data")

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "wordbook"
require_relative "gtk_driver"
require_relative "wn_fixture"

SHOTS = File.expand_path("../tmp/shots", __dir__)
FileUtils.rm_rf(SHOTS)

# A history the sidebar has to load from the settings on startup, which is the
# only way to see `load` and the 20-entry truncation do anything.
SEEDED_HISTORY = %w[alpha beta].freeze

FileUtils.mkdir_p(File.dirname(Wordbook::Utils::CONFIG_FILE))
File.write(
  Wordbook::Utils::CONFIG_FILE,
  JSON.pretty_generate(
    "behavior"   => { "live_search" => true, "pronunciations_accent" => "us" },
    "state"      => { "history" => SEEDED_HISTORY, "favorites" => [], "window_width" => 600, "window_height" => 400 },
    "appearance" => { "force_dark_mode" => false },
  ),
)

# The database the window's setup thread finds already extracted.
Wordbook::WnFixture.write(Wordbook::DatabaseManager.extracted_db_path)

# Walking the widget tree is how the content page is checked: the definition
# view builds its labels from the search result, so what they say is the only
# evidence the result reached the screen.
module Probe
  def self.descendants(widget)
    [].tap do |found|
      child = widget.first_child
      while child
        found << child
        found.concat(descendants(child))
        child = child.next_sibling
      end
    end
  end

  def self.with_class(widget, css_class)
    descendants(widget).select { |child| child.css_classes.include?(css_class) }
  end

  def self.texts(widget, css_class)
    with_class(widget, css_class).map { |label| label.text }
  end

  def self.buttons(widget, css_class)
    with_class(widget, css_class).select { |child| child.is_a?(Gtk::Button) }
  end

  def self.by_icon(widget, icon_name)
    descendants(widget).select { |child| child.is_a?(Gtk::Button) && child.icon_name == icon_name }
  end

  def self.labelled(widget, text)
    descendants(widget).select { |child| child.is_a?(Gtk::Button) && child.label == text }
  end
end

APP = Wordbook::Application.new

GtkDriver.drive(APP, shots: SHOTS, interval: 500, timeout: 180) do |d, app|
  window = -> { app.window }
  win = -> { app.window.window }
  content = -> { app.window.definition_view.listbox }
  sidebar = -> { app.window.sidebar }
  settings = -> { app.window.settings }

  d.window { app.window.window }

  # Firing a window action: `Gtk::Widget#activate_action` returns the widget
  # and activates nothing in these bindings — the previous round's driver
  # reported seven "win.<action> activates" checks that had in fact activated
  # nothing at all — so the action is activated the way GTK's accelerators and
  # menu items reach it, through the Gio::SimpleAction the window registered.
  fire = ->(name) { app.window.window.lookup_action(name).activate(nil) }

  # --- The window itself --------------------------------------------------

  d.step("the window builds and presents") do
    d.check("the window is an AdwApplicationWindow") { win.call.is_a?(Adwaita::ApplicationWindow) }
    d.check("the window is titled Wordbook") { win.call.title == "Wordbook" }
    d.check("the window is on screen") { win.call.visible? }
    d.check("the window takes its size from the settings") { win.call.default_width == 600 }
    d.check("the window takes its minimum size from the port") { win.call.size_request == [360, 280] }
    d.check("the content is the toast overlay") { win.call.content.equal?(window.call.toast_overlay) }
    d.check("the overlay holds the split view") { window.call.toast_overlay.child.equal?(window.call.split_view) }
    d.check("the split view holds the sidebar") { window.call.split_view.sidebar.is_a?(Gtk::Widget) }
    d.check("the split view holds the toolbar") { window.call.split_view.content.equal?(window.call.content_toolbar) }
    d.check("the header bar is the toolbar's top bar") do
      Probe.descendants(window.call.content_toolbar).include?(window.call.header_bar)
    end
    d.check("the search entry sits in the title") { window.call.title_clamp.child.equal?(window.call.search_box) }
    d.check("the search box holds the entry") { window.call.search_entry.parent.equal?(window.call.search_box) }
    d.check("the stack holds all five pages") do
      Wordbook::Window::PAGES.values.all? { |name| window.call.main_stack.get_child_by_name(name) }
    end
    d.check("the spinner page is an AdwSpinner") { window.call.spinner_page.is_a?(Adwaita::Spinner) }
    d.shot("01-startup")
  end

  # The accessible labels are built through Gtk::Builder, and getting them
  # wrong aborted this port's startup once; the widgets existing at all is the
  # evidence that Utils.accessible worked.
  d.step("the icon-only buttons were built with their accessible labels") do
    d.check("the search button is a GtkButton") { window.call.search_button.is_a?(Gtk::Button) }
    d.check("the sidebar toggle is a GtkToggleButton") do
      window.call.split_view_toggle_button.is_a?(Gtk::ToggleButton)
    end
    d.check("the menu button is a GtkMenuButton") { window.call.menu_button.is_a?(Gtk::MenuButton) }
    d.check("the favorites filter is a GtkToggleButton") do
      sidebar.call.favorites_filter_button.is_a?(Gtk::ToggleButton)
    end
    d.check("the clear-history button is a GtkButton") { sidebar.call.clear_history_button.is_a?(Gtk::Button) }
  end

  d.step("the stylesheet parses") do
    d.check("Style.install returns a provider") { Wordbook::Style.install.is_a?(Gtk::CssProvider) }
    d.check("the CSS loads without a parsing error") do
      [].then do |errors|
        Gtk::CssProvider.new.tap do |provider|
          provider.signal_connect("parsing-error") { |_p, _section, error| errors << error.message }
          provider.load(data: Wordbook::Style::CSS)
        end
        errors.empty?
      end
    end
  end

  d.step("the main menu model carries upstream's two sections") do
    Wordbook::MainMenu.new.build.then do |menu|
      d.check("the menu has two sections") { menu.n_items == 2 }
      d.check("the search section has three items") { menu.get_item_link(0, "section").n_items == 3 }
      d.check("the help section has three items") { menu.get_item_link(1, "section").n_items == 3 }
    end
  end

  d.step("the application registered its actions and accelerators") do
    %w[about shortcuts quit].each do |name|
      d.check("app.#{name} exists") { app.app.lookup_action(name).is_a?(Gio::Action) }
    end
    Wordbook::Window::WINDOW_ACTIONS.each do |name|
      d.check("win.#{name} exists") { win.call.lookup_action(name).is_a?(Gio::Action) }
    end
    # GTK stores an accelerator in its own spelling: `<Primary>` comes back as
    # `<Control>` and the modifiers come back in GDK's order, so what the port
    # declared is compared against that spelling of it rather than against the
    # literal string.
    {
      "app.quit"            => ["<Control>q"],
      "app.shortcuts"       => ["<Control>question"],
      "win.quit"            => ["<Control>w"],
      "win.search-selected" => ["<Control>s"],
      "win.random-word"     => ["<Control>r"],
      "win.paste-search"    => ["<Shift><Control>v"],
      "win.preferences"     => ["<Control>comma"],
      "win.toggle-sidebar"  => ["F9"],
      "win.toggle-menu"     => ["F10"],
    }.then do |expected|
      d.check("every action the port declares an accelerator for is covered") do
        expected.keys.sort == Wordbook::Application::APP_ACCELS.keys.sort
      end
      expected.each do |name, accels|
        d.check("#{name} is bound to #{accels.join(", ")}") { app.app.get_accels_for_action(name) == accels }
      end
    end
  end

  # --- The database comes up ----------------------------------------------

  d.step("wait for the database setup thread") { nil }

  d.step("the database setup leaves the window on the welcome page") do
    d.check("the welcome page is showing") { window.call.main_stack.visible_child_name == "welcome_page" }
    d.check("the header is sensitive again") { window.call.title_clamp.sensitive? }
    d.check("the welcome page is an AdwStatusPage") { window.call.welcome_page.is_a?(Adwaita::StatusPage) }
    d.check("the welcome page names the app") { window.call.welcome_page.title == "Wordbook" }
    d.check("the database manager reports a usable database") { Wordbook::DatabaseManager.setup }
    d.shot("02-welcome")
  end

  d.step("the sidebar loaded the history from the settings") do
    d.check("both seeded terms are in the store") { sidebar.call.terms == SEEDED_HISTORY }
    d.check("the sidebar shows its list") { sidebar.call.stack.visible_child_name == "list" }
    d.check("the clear button is sensitive") { sidebar.call.clear_history_button.sensitive? }
    d.check("each term has a row") { sidebar.call.listbox.get_row_at_index(1).is_a?(Gtk::ListBoxRow) }
    d.check("the rows are styled as history items") do
      sidebar.call.listbox.get_row_at_index(0).css_classes.include?("history-item")
    end
  end

  # --- Searching ----------------------------------------------------------

  # Live search is on, so typing is the whole interaction: the entry's changed
  # handler starts a 400ms timer and the search runs off it.
  d.step("typing a term starts a live search") do
    window.call.search_entry.text = "word"
    d.check("the clear icon appears") { window.call.search_entry.secondary_icon_name == "edit-clear-symbolic" }
    d.check("the search button is hidden while live search is on") { !window.call.search_button.visible? }
  end

  d.step("wait for the live search") { nil }

  d.step("the content page shows the definitions") do
    d.check("the content page is showing") { window.call.main_stack.visible_child_name == "content_page" }
    d.check("one row per part of speech") { Probe.texts(content.call, "pos-header") == %w[noun verb phrase] }
    d.check("the noun definition is on the page") do
      Probe.texts(content.call, "definition").include?("a unit of language that native speakers can identify")
    end
    d.check("the verb definition is on the page") do
      Probe.texts(content.call, "definition").include?("to express in words")
    end
    d.check("the examples are on the page") do
      Probe.texts(content.call, "example-text").sort == ["he said a word in my ear", "mark my words",
                                                         "the letter was worded carefully",]
    end
    d.check("the definitions are numbered") { Probe.texts(content.call, "definition-number").include?("1") }
    d.check("the lemma headers are the matched lemma") do
      Probe.texts(content.call, "synset-header").uniq == ["word"]
    end
    d.check("the American IPA is shown") { Probe.texts(content.call, "dimmed").include?("/wɜːd/") }
    d.check("every relation group is built") do
      Probe.texts(content.call, "relation-type").uniq == ["Synonyms:", "Antonyms:", "Similar to:", "Also see:"]
    end
    d.check("the related lemmas are chips") do
      Probe.buttons(content.call, "lemma-button").map(&:label).sort ==
        %w[lexicon silence speak term vocable wordbook]
    end
    d.check("each definition carries the Search Selected Text menu") do
      Probe.with_class(content.call, "definition").all? { |label| label.extra_menu.is_a?(Gio::MenuModel) }
    end
    d.shot("03-definitions")
  end

  d.step("the pronunciation row reads the lemma aloud") do
    Probe.by_icon(content.call, "audio-volume-high-symbolic").then do |buttons|
      d.check("every lemma header has a speak button") { buttons.length == 3 }
      buttons.first.activate
      d.check("espeak-ng is reachable") { !Wordbook::Espeak.pronunciation("word", "us").to_s.empty? }
      d.check("the IPA converts to espeak phonemes") do
        Wordbook::Espeak.ipa_to_espeak("/wɜːd/") == "[[w3:d]]"
      end
    end
  end

  d.step("clicking a synonym searches it") do
    Probe.buttons(content.call, "lemma-button").find { |button| button.label == "term" }.activate
  end

  d.step("the synonym's own definition is on screen") do
    d.check("the entry holds the synonym") { window.call.search_entry.text == "term" }
    d.check("the page is the synonym's") { Probe.texts(content.call, "synset-header").uniq == ["term"] }
    d.check("the matched lemma's synonyms are the others") do
      Probe.buttons(content.call, "lemma-button").map(&:label).include?("word")
    end
  end

  # An inflection: "words" is a rank-1 form of the "word" entry, so the lemma
  # the page shows has to be the rank-0 one.
  d.step("an inflected form resolves to its lemma") { window.call.trigger_search("words") }

  d.step("the inflection landed on the lemma") do
    d.check("the header is the lemma") { Probe.texts(content.call, "synset-header").uniq == ["word"] }
  end

  # The history is written 2000ms after the typing settles, which is four of
  # these ticks.
  d.step("wait for the deferred history write (1/4)") { nil }
  d.step("wait for the deferred history write (2/4)") { nil }
  d.step("wait for the deferred history write (3/4)") { nil }
  d.step("wait for the deferred history write (4/4)") { nil }

  # Upstream's deferred write keeps only the term that was on screen when the
  # typing settled, which is why three searches in a row leave one entry and
  # not three.
  d.step("live search defers the history until the typing settles") do
    d.check("the last searched term was recorded, newest first") do
      sidebar.call.terms == ["word", "alpha", "beta"]
    end
    d.check("the intermediate term was not recorded") { !sidebar.call.terms.include?("term") }
    d.shot("04-history")
  end

  # --- The failure and empty states ---------------------------------------

  d.step("a near miss offers suggestions") { window.call.trigger_search("wordz") }

  d.step("the no-definition page offers the closest word") do
    d.check("the failure page is showing") { window.call.main_stack.visible_child_name == "search_fail_page" }
    d.check("the page says no definition was found") do
      window.call.search_fail_page.title == "No definition found"
    end
    d.check("the suggestion is a search link") do
      window.call.search_fail_description_label.label == %(Did you mean: <a href="search;word">word</a>?)
    end
    d.check("the suggestion label is visible") { window.call.search_fail_description_label.visible? }
    d.shot("05-no-definition")
  end

  d.step("activating a suggestion searches it") do
    d.check("the label handled the link") do
      window.call.search_fail_description_label.signal_emit("activate-link", "search;word")
    end
  end

  d.step("the suggestion's definition is on screen") do
    d.check("the content page came back") { window.call.main_stack.visible_child_name == "content_page" }
    d.check("the entry holds the suggestion") { window.call.search_entry.text == "word" }
  end

  # Under three characters there is nothing to suggest, and upstream hides the
  # description rather than showing an empty "Did you mean:".
  d.step("a two-letter miss offers nothing") { window.call.trigger_search("xq") }

  d.step("the no-definition page hides its empty description") do
    d.check("the failure page is showing") { window.call.main_stack.visible_child_name == "search_fail_page" }
    d.check("the description is empty") { window.call.search_fail_description_label.label == "" }
    d.check("the description is hidden") { !window.call.search_fail_description_label.visible? }
  end

  # --- The preferences dialog ---------------------------------------------

  # The accent change below re-renders whatever search is on screen, so there
  # has to be one.
  d.step("put a definition back on screen") { window.call.trigger_search("word") }

  d.step("the preferences dialog opens") do
    d.check("the content page is showing") { window.call.main_stack.visible_child_name == "content_page" }
    fire.call("preferences")
  end

  d.step("every preference row is built from the stored settings") do
    win.call.visible_dialog.then do |dialog|
      d.check("the dialog is the preferences dialog") { dialog.is_a?(Wordbook::SettingsDialog) }
      d.check("live search starts on") { dialog.live_search_switch.active? }
      d.check("double click starts off") { !dialog.double_click_switch.active? }
      d.check("auto paste starts off") { !dialog.auto_paste_switch.active? }
      d.check("dark mode starts off") { !dialog.dark_ui_switch.active? }
      d.check("the accent row starts on American English") { dialog.pronunciations_accent_row.selected.zero? }
      d.check("the accent row lists both accents") { dialog.pronunciations_accent_row.model.n_items == 2 }
      d.shot("06-preferences")
    end
  end

  d.step("flipping the switches writes the settings and changes the window") do
    win.call.visible_dialog.then do |dialog|
      dialog.double_click_switch.active = true
      dialog.auto_paste_switch.active = true
      dialog.dark_ui_switch.active = true
      dialog.live_search_switch.active = false
      d.check("double click was stored") { settings.call.double_click }
      d.check("auto paste was stored") { settings.call.auto_paste_on_launch }
      d.check("dark mode was stored") { settings.call.gtk_dark_ui }
      d.check("dark mode forced the colour scheme") do
        Adwaita::StyleManager.default.color_scheme == Adwaita::ColorScheme::FORCE_DARK
      end
      d.check("live search was stored off") { !settings.call.live_search }
      d.check("the search button came back") { window.call.search_button.visible? }
      dialog.pronunciations_accent_row.selected = 1
      d.check("the accent was stored") { settings.call.pronunciations_accent.code == "gb" }
    end
  end

  d.step("the accent change re-renders the page") do
    d.check("the British IPA replaced the American one") do
      Probe.texts(content.call, "dimmed").include?("/wəːd/")
    end
    d.check("the re-render did not record the term again") { sidebar.call.terms.first == "word" }
    d.shot("07-british-accent")
    win.call.visible_dialog&.close
  end

  # --- The search button, the error dialog and the welcome state ----------

  d.step("the search button searches what is in the entry") do
    window.call.search_entry.text = "dictionary"
    window.call.search_button.activate
  end

  # "dictionary" has no pronunciation in WordNet, so the espeak-ng fallback
  # pass is what puts an IPA on its header.
  d.step("a lemma WordNet has no pronunciation for borrows one from espeak-ng") do
    d.check("the content page is showing") { window.call.main_stack.visible_child_name == "content_page" }
    d.check("the header is the searched lemma") { Probe.texts(content.call, "synset-header").uniq == ["dictionary"] }
    d.check("a fallback IPA is shown") do
      Probe.texts(content.call, "dimmed").first.then { |ipa| !ipa.to_s.empty? && ipa != "/wəːd/" }
    end
    d.shot("08-fallback-pronunciation")
  end

  d.step("an empty entry goes back to the welcome page") do
    window.call.search_entry.text = ""
    window.call.search_button.activate
  end

  d.step("the welcome page is back") do
    d.check("the welcome page is showing") { window.call.main_stack.visible_child_name == "welcome_page" }
    d.check("the definition view was cleared") { content.call.first_child.nil? }
  end

  # Input that cleans away to nothing is the one search that raises the alert
  # rather than switching a page — and only with live search off, which it now
  # is.
  d.step("input that cleans away to nothing reports itself") do
    window.call.search_entry.text = "???"
    window.call.search_button.activate
  end

  d.step("the invalid-input alert is up") do
    win.call.visible_dialog.then do |dialog|
      d.check("an AdwAlertDialog is open") { dialog.is_a?(Adwaita::AlertDialog) }
      d.check("it names the problem") { dialog.heading == "Invalid input" }
      d.check("it offers one response") { dialog.has_response?("dismiss") }
      d.shot("09-invalid-input")
      dialog.close
    end
  end

  # --- The completion popover ---------------------------------------------

  d.step("typing with live search off offers completions") do
    window.call.search_entry.text = ""
    window.call.search_entry.grab_focus
    window.call.completion.update("wor")
  end

  d.step("the completion popover lists the wordlist's matches") do
    window.call.completion.then do |completion|
      d.check("the popover is up") { completion.popover.visible? }
      d.check("it offers both prefix matches, shortest first") do
        Probe.descendants(completion.listbox).select { |child| child.is_a?(Gtk::Label) }
             .map(&:text) == %w[word wordbook]
      end
      d.check("the entry is marked active") { window.call.search_entry.css_classes.include?("completion-active") }
      # A popover is its own surface, so the window's snapshot never holds it;
      # it is shot as the widget it is.
      d.shot("10-completion", completion.popover)
    end
  end

  d.step("the arrow keys move the selection and Tab completes it") do
    window.call.completion.then do |completion|
      d.check("Down selects the first row") { completion.key_pressed(Gdk::Keyval::KEY_Down) }
      d.check("the first row is selected") { completion.listbox.selected_row&.index&.zero? }
      d.check("Down again selects the second") do
        completion.key_pressed(Gdk::Keyval::KEY_Down)
        completion.listbox.selected_row&.index == 1
      end
      d.check("Up goes back") do
        completion.key_pressed(Gdk::Keyval::KEY_Up)
        completion.listbox.selected_row&.index&.zero?
      end
      d.check("Tab completes the entry") do
        completion.key_pressed(Gdk::Keyval::KEY_Tab)
        window.call.search_entry.text == "word"
      end
      d.check("completing closed the popover") { !completion.popover.visible? }
    end
  end

  d.step("Escape closes the popover and Return searches the selection") do
    window.call.completion.then do |completion|
      window.call.search_entry.text = "wor"
      completion.update("wor")
      d.check("the popover reopened") { completion.popover.visible? }
      d.check("Escape is consumed") { completion.key_pressed(Gdk::Keyval::KEY_Escape) }
      d.check("Escape closed it") { !completion.popover.visible? }
      completion.update("wor")
      completion.key_pressed(Gdk::Keyval::KEY_Down)
      d.check("Return is consumed") { completion.key_pressed(Gdk::Keyval::KEY_Return) }
    end
  end

  d.step("the completion's Return searched the highlighted word") do
    d.check("the entry holds the completed word") { window.call.search_entry.text == "word" }
    d.check("the content page is showing") { window.call.main_stack.visible_child_name == "content_page" }
  end

  # --- The keyboard -------------------------------------------------------

  # A printable key with the entry unfocused appends to the entry and moves the
  # focus there, which is how a search starts without the mouse.
  d.step("a printable key with the entry unfocused types into it") do
    window.call.search_entry.text = ""
    window.call.menu_button.grab_focus
    d.check("the key was consumed") do
      window.call.key_controller.signal_emit("key-pressed", Gdk::Keyval::KEY_a, 38, 0)
    end
    d.check("the character landed in the entry") { window.call.search_entry.text == "a" }
    d.check("the entry took the focus") { window.call.completion.entry_has_focus? }
  end

  d.step("a modified key is left to the shortcut it belongs to") do
    window.call.search_entry.text = ""
    window.call.menu_button.grab_focus
    d.check("Ctrl+a is not consumed") do
      !window.call.key_controller.signal_emit(
        "key-pressed",
        Gdk::Keyval::KEY_a,
        38,
        Gdk::ModifierType::CONTROL_MASK.to_i,
      )
    end
    d.check("nothing was typed") { window.call.search_entry.text == "" }
  end

  # --- The sidebar --------------------------------------------------------

  d.step("activating a history row searches its term") do
    sidebar.call.listbox.get_row_at_index(0).then do |row|
      sidebar.call.listbox.signal_emit("row-activated", row)
    end
  end

  d.step("the history row's term is on screen") do
    d.check("the content page is showing") { window.call.main_stack.visible_child_name == "content_page" }
    d.check("the entry holds the row's term") { window.call.search_entry.text == sidebar.call.terms.first }
  end

  d.step("the star button favourites a term") do
    sidebar.call.listbox.get_row_at_index(0).then do |row|
      Probe.by_icon(row, Wordbook::HistoryRow::UNSTARRED).first.activate
    end
  end

  d.step("the favourite was recorded and the row restyled") do
    sidebar.call.terms.first.then do |term|
      d.check("the settings remember the favourite") { settings.call.favorite?(term) }
      d.check("the row is styled as a favourite") do
        sidebar.call.listbox.get_row_at_index(0).css_classes.include?("favorite-item")
      end
      d.check("the star filled in") do
        Probe.by_icon(sidebar.call.listbox.get_row_at_index(0), Wordbook::HistoryRow::STARRED).length == 1
      end
    end
  end

  d.step("the favourites filter hides everything else") do
    fire.call("toggle-favorites")
    d.check("the filter button is active") { sidebar.call.favorites_filter_button.active? }
    d.check("the sidebar is filtering") { sidebar.call.favorites_only? }
    d.check("the filter button shows a filled star") do
      sidebar.call.favorites_filter_button.icon_name == Wordbook::HistoryRow::STARRED
    end
    d.check("the favourite row is still visible") { sidebar.call.listbox.get_row_at_index(0).visible? }
    d.check("the rest are hidden") { !sidebar.call.listbox.get_row_at_index(1).visible? }
    d.shot("11-favorites-only")
  end

  d.step("the filter comes off again") do
    fire.call("toggle-favorites")
    d.check("the filter button is off") { !sidebar.call.favorites_filter_button.active? }
    d.check("the hidden rows came back") { sidebar.call.listbox.get_row_at_index(1).visible? }
  end

  d.step("clearing the history keeps the favourites") do
    sidebar.call.terms.first.then { |term| @favourite = term }
    sidebar.call.clear_history_button.activate
  end

  d.step("only the favourite survived, and a toast offers the rest back") do
    d.check("the favourite is the only term left") { sidebar.call.terms == [@favourite] }
    d.check("the clear button is still sensitive") { sidebar.call.clear_history_button.sensitive? }
    d.check("a toast is in the overlay") do
      Probe.labelled(window.call.toast_overlay, "Undo").length == 1
    end
    d.shot("12-cleared-with-toast")
  end

  d.step("the toast's Undo puts the history back") do
    Probe.labelled(window.call.toast_overlay, "Undo").first.activate
  end

  d.step("the cleared terms came back in their places") do
    d.check("every term is back") { sidebar.call.terms.length > 1 }
    d.check("the favourite is still first") { sidebar.call.terms.first == @favourite }
  end

  # The empty state: with nothing favourited, a clear empties the store, and
  # the sidebar swaps its list for the status page.
  d.step("un-favouriting and clearing again empties the sidebar") do
    sidebar.call.listbox.get_row_at_index(0).then do |row|
      Probe.by_icon(row, Wordbook::HistoryRow::STARRED).first.activate
    end
    sidebar.call.clear_history_button.activate
  end

  d.step("the sidebar shows its empty state") do
    d.check("the store is empty") { sidebar.call.terms.empty? }
    d.check("the empty page is showing") { sidebar.call.stack.visible_child_name == "empty" }
    d.check("the empty page says so") do
      sidebar.call.empty_page.title == "No recent searches or favorites"
    end
    d.check("the clear button went insensitive") { !sidebar.call.clear_history_button.sensitive? }
    d.shot("13-empty-history")
  end

  # --- The remaining window actions ---------------------------------------

  d.step("the random word action searches something from the wordlist") do
    fire.call("random-word")
  end

  d.step("the random word landed on a definition") do
    d.check("the content page is showing") { window.call.main_stack.visible_child_name == "content_page" }
    d.check("the entry holds a word from the lexicon") do
      %w[word term vocable silence speak dictionary wordbook lexicon].include?(window.call.search_entry.text)
    end
    d.check("it was recorded in the history") { sidebar.call.terms.length == 1 }
  end

  d.step("the sidebar toggle action closes the sidebar") do
    fire.call("toggle-sidebar")
    d.check("the toggle button went off") { !window.call.split_view_toggle_button.active? }
    d.check("the split view hid its sidebar") { !window.call.split_view.show_sidebar? }
    fire.call("toggle-sidebar")
    d.check("toggling again brings it back") { window.call.split_view.show_sidebar? }
  end

  d.step("the menu action opens the menu") do
    fire.call("toggle-menu")
    d.check("the menu button is active") { window.call.menu_button.active? }
    d.check("the popover rendered upstream's six items") do
      Probe.descendants(window.call.menu_button.popover)
           .select { |child| child.is_a?(Gtk::Label) }
           .map { |label| label.text.delete("_") }
           .then do |labels|
        ["Paste & Search", "Search Selected Text", "Random Word",
         "Preferences", "Keyboard Shortcuts", "About Wordbook",].all? { |title| labels.include?(title) }
      end
    end
    d.shot("14-main-menu", window.call.menu_button.popover)
    window.call.menu_button.active = false
  end

  d.step("paste-and-search reads the clipboard") do
    window.call.clipboard.set("lexicon")
    fire.call("paste-search")
  end

  d.step("the clipboard's term was searched") do
    d.check("the content page is showing") { window.call.main_stack.visible_child_name == "content_page" }
    d.check("the entry holds the pasted term") { window.call.search_entry.text == "lexicon" }
  end

  # "Search Selected Text" is disabled until the primary selection has
  # something in it, which is upstream's behaviour and the one refusal this
  # window makes.
  # The empty primary selection is the crash this driver found: the handler
  # rescued GLib::Error, the bindings raise Gio::Error, and reading an empty
  # selection ended the process (FINDINGS.md, defect 11). Emitting the signal
  # the clipboard emits is the path that killed it.
  d.step("an empty primary selection is survived") do
    window.call.primary_clipboard.signal_emit("changed")
  end

  d.step("search-selected is disabled with nothing selected") do
    d.check("the application is still running") { win.call.visible? }
    d.check("the action starts disabled") { !win.call.lookup_action("search-selected").enabled? }
    window.call.primary_clipboard.set("silence")
  end

  d.step("a primary selection enables search-selected") do
    d.check("the action is enabled now") { win.call.lookup_action("search-selected").enabled? }
    fire.call("search-selected")
  end

  d.step("the selected text was searched") do
    d.check("the entry holds the selection") { window.call.search_entry.text == "silence" }
    d.check("the content page is showing") { window.call.main_stack.visible_child_name == "content_page" }
  end

  # --- The dialogs --------------------------------------------------------

  d.step("the about dialog opens") { app.app.activate_action("about", nil) }

  d.step("the about dialog carries upstream's metadata") do
    win.call.visible_dialog.then do |dialog|
      d.check("the dialog is an AdwAboutDialog") { dialog.is_a?(Adwaita::AboutDialog) }
      d.check("it names the app") { dialog.application_name == "Wordbook" }
      d.check("it carries the port's version") { dialog.version == Wordbook::Rb::VERSION }
      d.check("it names the developer") { dialog.developer_name == "Mufeed Ali" }
      d.check("it is GPL-3.0") { dialog.license_type == Gtk::License::GPL_3_0 }
      d.shot("15-about")
      dialog.close
    end
  end

  d.step("the shortcuts dialog opens") { app.app.activate_action("shortcuts", nil) }

  d.step("the shortcuts dialog lists upstream's eight rows") do
    win.call.visible_dialog.then do |dialog|
      d.check("the dialog is an AdwShortcutsDialog") { dialog.is_a?(Adwaita::ShortcutsDialog) }
      Probe.descendants(dialog).select { |child| child.is_a?(Gtk::Label) }.map(&:text).then do |labels|
        d.check("it lists upstream's eight shortcuts") do
          ["Show Shortcuts", "Preferences", "Paste and Search", "Random Word",
           "Search Selected Text", "Toggle Sidebar", "Show Menu", "Quit",].all? { |title| labels.include?(title) }
        end
        d.check("it names the General section") { labels.include?("General") }
      end
      d.check("the accelerators came from the application's bindings") do
        Probe.descendants(dialog).select { |child| child.is_a?(Adwaita::ShortcutLabel) }
             .map(&:accelerator).uniq.sort ==
          ["<Control>comma", "<Control>question", "<Control>r", "<Control>s",
           "<Control>w", "<Shift><Control>v", "F10", "F9",]
      end
      d.shot("16-shortcuts")
      dialog.close
    end
  end

  # --- The responsive breakpoint ------------------------------------------

  d.step("a phone-width window collapses the split view") do
    d.check("the split view is open while the window is wide") { !window.call.split_view.collapsed? }
    win.call.set_default_size(420, 600)
  end

  d.step("the breakpoint fired") do
    d.check("the split view collapsed") { window.call.split_view.collapsed? }
    d.shot("17-narrow")
    win.call.set_default_size(900, 640)
  end

  d.step("widening releases it again") do
    d.check("the split view is open again") { !window.call.split_view.collapsed? }
    window.call.split_view.show_sidebar = false
    d.check("the toggle button follows show-sidebar") { !window.call.split_view_toggle_button.active? }
    window.call.split_view_toggle_button.active = true
    d.check("show-sidebar follows the toggle button") { window.call.split_view.show_sidebar? }
    d.shot("18-wide")
  end

  # --- The database error page --------------------------------------------

  # The page the window lands on when there is no database, and the condition
  # that produces it: nothing in this checkout ships the compressed archive,
  # so the lookup for one still comes back empty even though the extracted
  # fixture is in place.
  d.step("the database error page renders") do
    d.check("no compressed archive is installed here") { Wordbook::DatabaseManager.find_compressed_db.nil? }
    d.check("extraction reports failure when there is nothing to extract") do
      !Wordbook::DatabaseManager.extract_if_available
    end
    window.call.main_stack.visible_child_name = "db_error_page"
  end

  d.step("the error page names the problem and offers a way out") do
    d.check("the error page is showing") { window.call.main_stack.visible_child_name == "db_error_page" }
    d.check("it says the database was not found") { window.call.db_error_page.title == "Database not found" }
    d.check("it asks for a reinstall") do
      window.call.db_error_page.description == "Installation is incomplete. Please reinstall Wordbook."
    end
    d.check("it offers an exit button") { window.call.exit_button.label == "Exit" }
    d.shot("19-database-error")
    window.call.main_stack.visible_child_name = "welcome_page"
  end

  # --- The shell search provider ------------------------------------------

  # A service of its own rather than part of the window, so it is driven
  # directly: the shell calls these five methods over D-Bus.
  d.step("the shell search provider answers the overview's searches") do
    Wordbook::ShellSearchProvider.new(wordnet: Wordbook::Base.wordnet).then do |provider|
      d.check("its interface describes SearchProvider2") do
        provider.interface_info.name == "org.gnome.Shell.SearchProvider2"
      end
      provider.initial_result_set(["word"]).then do |ids|
        d.check("a term returns one id per part of speech") { ids.length == 3 }
        provider.result_metas(ids).then do |metas|
          d.check("every meta names the lemma") { metas.map { |meta| meta["name"] }.uniq == ["word"] }
          d.check("every meta describes the synset") do
            metas.map { |meta| meta["description"] }.include?("to express in words")
          end
        end
        d.check("a narrowed search answers the same way") do
          provider.subsearch_result_set(ids, ["word"]).length == 3
        end
      end
      d.check("a term with no definition returns nothing") { provider.initial_result_set(["zzzqqq"]).empty? }
    end
  end

  # --- Shutting down ------------------------------------------------------

  d.step("saving the state writes the history and the window size") do
    window.call.save_state
    JSON.parse(File.read(Wordbook::Utils::CONFIG_FILE)).then do |stored|
      d.check("the history was written") { stored["state"]["history"] == sidebar.call.terms }
      d.check("the window size was written") { stored["state"]["window_width"] == win.call.default_width }
      d.check("the favourites were written") { stored["state"]["favorites"].is_a?(Array) }
    end
  end

  # Last, and in one step: closing the last window quits the application, which
  # ends the run.
  d.step("the quit action closes the window") do
    fire.call("quit")
    d.check("the window closed") { !win.call.visible? }
  end
end
