# frozen_string_literal: true

require "adwaita"

require_relative "base"
require_relative "database_manager"
require_relative "definition_view"
require_relative "error_dialog"
require_relative "espeak"
require_relative "history_sidebar"
require_relative "main_menu"
require_relative "search_completion"
require_relative "settings"
require_relative "settings_dialog"
require_relative "translations"
require_relative "utils"

module Wordbook
  # Window is the main window: the search entry in the header bar, the history
  # sidebar beside the definitions, and the stack of pages the search moves
  # between — welcome, definitions, "no definition found", the database error
  # and the spinner.
  #
  # Ported from upstream's data/resources/ui/window.blp and
  # wordbook/window.py.
  #
  # The responsive collapse is the `Adw.Breakpoint` upstream declares on the
  # template (`data/resources/ui/window.blp:54`): an
  # `Adwaita::BreakpointCondition` parsed from `max-width: 550sp`, with one
  # setter putting `collapsed` on the split view, installed on the window with
  # `add_breakpoint`. libadwaita evaluates it against the window's allocation,
  # so it fires on every resize and scales the threshold by the text scaling
  # factor itself.
  # Upstream: `window.blp:54-60`. Port: `collapse_breakpoint` below.
  #
  # A search is superseded by bumping a generation counter rather than by
  # setting a threading.Event: a result whose generation is stale is dropped
  # when it comes back, which is what cancelling it achieved.
  #
  class Window
    include Translations

    PAGES = {
      welcome:     "welcome_page",
      content:     "content_page",
      search_fail: "search_fail_page",
      db_error:    "db_error_page",
      spinner:     "spinner_page",
    }.freeze

    LIVE_SEARCH_DELAY = 400
    HISTORY_DELAY = 2000
    SPEAK_SPEED = 120

    # The blp's breakpoint condition, verbatim. An `sp` is a
    # density-independent pixel, which libadwaita multiplies by the text
    # scaling factor when it evaluates the condition.
    COLLAPSE_CONDITION = "max-width: 550sp"

    MIN_WIDTH = 360
    MIN_HEIGHT = 280
    SEARCH_LINK_PREFIX = "search;"

    # Upstream gates the quick-search on
    # `state & Gtk.accelerator_get_default_mod_mask() in (SHIFT_MASK, 0)`
    # (`window.py:549-555`): any modifier in the default mask other than Shift
    # means the key belongs to a shortcut. This is that mask without Shift.
    # Hyper was missing from it at first, so Hyper+a typed an "a" into the
    # entry here where upstream let the key through.
    SHORTCUT_MASK = [
      Gdk::ModifierType::CONTROL_MASK,
      Gdk::ModifierType::ALT_MASK,
      Gdk::ModifierType::SUPER_MASK,
      Gdk::ModifierType::HYPER_MASK,
      Gdk::ModifierType::META_MASK,
    ].sum(&:to_i)

    WINDOW_ACTIONS = %w[
      paste-search
      toggle-sidebar
      toggle-menu
      preferences
      random-word
      search-selected
      toggle-favorites
      quit
    ].freeze

    attr_reader :settings

    def initialize(app, term: nil, auto_paste_requested: false, settings: Settings.get, development_mode: false)
      @app = app
      @lookup_term = term
      @auto_paste_requested = auto_paste_requested
      @settings = settings
      @development_mode = development_mode
      @wordlist = []
      @search_generation = 0
      @searched_term = nil
      @primary_clipboard_text = nil
      @auto_paste_queued = false
    end

    def build
      window.tap do |win|
        win.content = toast_overlay

        toast_overlay.tap do |overlay|
          overlay.child = split_view

          split_view.tap do |view|
            view.sidebar = sidebar.build
            view.content = content_toolbar

            split_view.bind_property(
              "show-sidebar",
              split_view_toggle_button,
              "active",
              GLib::BindingFlags::BIDIRECTIONAL | GLib::BindingFlags::SYNC_CREATE,
            )

            content_toolbar.tap do |toolbar|
              toolbar.add_top_bar(header_bar)
              toolbar.content = main_scroll

              header_bar.tap do |header|
                header.title_widget = title_clamp
                header.pack_start(split_view_toggle_button)
                header.pack_end(menu_button)

                title_clamp.child = search_box

                search_box.tap do |box|
                  box.append(search_entry)
                  box.append(search_button)

                  search_button.signal_connect("clicked") { on_search_clicked }
                  connect_entry
                end
              end

              main_scroll.tap do |scroll|
                scroll.child = main_clamp
                main_clamp.child = main_stack

                main_stack.tap do |stack|
                  stack.add_named(welcome_page, PAGES[:welcome])
                  stack.add_named(definition_view.build, PAGES[:content])
                  stack.add_named(search_fail_page, PAGES[:search_fail])
                  stack.add_named(db_error_page, PAGES[:db_error])
                  stack.add_named(spinner_page, PAGES[:spinner])

                  search_fail_page.child = search_fail_description_label
                  search_fail_description_label.signal_connect("activate-link") do |_label, uri|
                    activate_link(uri)
                  end

                  db_error_page.child = exit_button
                  exit_button.signal_connect("clicked") { exit_immediately }
                end
              end
            end
          end
        end

        key_controller.tap do |controller|
          controller.signal_connect("key-pressed") { |_c, keyval, _code, state| quick_search_key(keyval, state) }
        end
        win.add_controller(key_controller)

        # The blp declares both of these on the template, so they are set when
        # the window is built rather than once the database has finished
        # extracting: the entry is focused while the spinner is still up, and
        # Return presses the search button whatever the live-search setting is.
        win.focus_widget = search_entry
        win.default_widget = search_button

        win.add_breakpoint(collapse_breakpoint)

        win.signal_connect("notify::is-active") { paste_when_active }
        win.signal_connect("close-request") { save_state_and_close }

        completion.build
        setup_actions
        load_history
        apply_live_search_visibility
        setup_wordnet
      end
    end

    def present = window.present

    # --- The API the dialogs and the application use ------------------------

    def completion_enabled=(enabled)
      completion.enabled = enabled
    end

    # Upstream's refresh_current_search_pronunciations: re-runs the search that
    # is on screen so the new accent's IPA is shown, without recording the term
    # in the history a second time.
    def refresh_current_search_pronunciations
      if @searched_term && main_stack.visible_child_name == PAGES[:content]
        on_search_clicked(text: @searched_term, update_history: false)
      end
    end

    # Fills the entry with a term and searches it, with the entry's own changed
    # handler blocked so live search does not fire a second search for it.
    def trigger_search(text)
      unless text.to_s.strip.empty?
        search_entry.signal_handler_block(entry_changed_handler) do
          search_entry.text = text
          search_entry.position = text.length
        end
        on_search_clicked(text: text)
      end
    end

    # Auto-paste has to wait for the window to be focused, or the primary
    # selection it reads would not be the user's.
    def queue_auto_paste
      if window.is_active?
        GLib::Idle.add { paste_and_search }
      else
        @auto_paste_queued = true
      end
    end

    # Upstream's save_state: the pending timers are dropped, and the history
    # and window size are written in one update.
    def save_state
      cancel_timer(:live_search)
      cancel_timer(:history)
      @settings.batch_update(
        "history"       => sidebar.terms,
        "window_width"  => window.default_width,
        "window_height" => window.default_height,
      )
    end

    # --- Searching -----------------------------------------------------------

    def on_search_clicked(text: nil, update_history: true)
      cancel_timer(:live_search)
      completion.clear
      definition_view.clear
      (text || search_entry.text.strip).then do |term|
        if term.strip.empty?
          page_switch(:welcome)
        else
          start_search(term, update_history)
        end
      end
    end

    private

      # The lookup happens off the main thread, as upstream's does, because a
      # cold database read is slow enough to drop frames.
      def start_search(term, update_history)
        @search_generation += 1
        page_switch(:spinner)
        generation = @search_generation
        Thread.new do
          Thread.current.name = "search"
          search_in_background(term, generation, update_history)
        end
      end

      def search_in_background(term, generation, update_history)
        with_suggestions(term, search(term)).then do |result|
          GLib::Idle.add do
            if generation == @search_generation
              on_search_finished(term, result, update_history)
            end
            false
          end
        end
      rescue StandardError => e
        Utils.log_error("Search for '#{term}' failed: #{e.message}")
      end

      # A term with no definition gets the closest words from the wordlist, so
      # the failure page can offer them.
      def with_suggestions(term, result)
        if result && result[:result].nil?
          result.merge(suggestions: Base.suggestions(term, @wordlist))
        else
          result
        end
      end

      def search(search_text)
        Base.clean_search_terms(search_text).then do |text|
          if text.strip.empty?
            report_invalid_input
          else
            lookup(text)
          end
        end
      end

      def lookup(text)
        if @wordnet
          Base.format_output(text, @wordnet, accent: @settings.pronunciations_accent.code)
        end
      end

      # Only reported when live search is off: with it on, every half-typed
      # term would raise it.
      def report_invalid_input
        unless @settings.live_search
          GLib::Idle.add do
            show_error(_("Invalid input"), _("Nothing definable was found in your search input"))
            false
          end
        end
        nil
      end

      def on_search_finished(search_term, result, update_history)
        @searched_term = search_term
        if result.nil?
          page_switch(:welcome)
        else
          if result[:result]
            show_definitions(result, update_history)
          else
            show_search_failure(result)
          end
        end
      end

      def show_definitions(result, update_history)
        definition_view.populate(result[:result])
        page_switch(:content)
        if update_history
          record_history(result[:term])
        end
      end

      # With live search on, the term is only remembered once the typing has
      # settled, so a search for "dictionary" does not leave nine prefixes
      # behind it.
      def record_history(term)
        if @settings.live_search
          @pending_history_term = term
          restart_timer(:history, HISTORY_DELAY) { add_pending_history }
        else
          sidebar.add(term)
        end
      end

      def add_pending_history
        if @pending_history_term
          sidebar.add(@pending_history_term)
          @pending_history_term = nil
        end
        timers[:history] = nil
        false
      end

      def show_search_failure(result)
        suggestion_markup(result[:suggestions]).then do |markup|
          search_fail_description_label.markup = markup
          search_fail_description_label.visible = !markup.empty?
        end
        page_switch(:search_fail)
      end

      # The suggestions are links the label handles itself through
      # activate-link, which is how clicking one starts its search.
      def suggestion_markup(suggestions)
        Array(suggestions).map { |word, _score| %(<a href="#{SEARCH_LINK_PREFIX}#{word}">#{word}</a>) }
                          .then do |links|
          if links.empty?
            ""
          else
            format(_("Did you mean: %s?"), links.join(", "))
          end
        end
      end

      def activate_link(uri)
        if uri.to_s.start_with?(SEARCH_LINK_PREFIX)
          trigger_search(uri[SEARCH_LINK_PREFIX.length..])
        end
        true
      end

      # --- Pages ------------------------------------------------------------

      # Switched from an idle callback, as upstream does, so a page change
      # requested from a search thread's callback lands after the widgets it
      # just built have settled.
      def page_switch(page)
        Utils.log_info("Switching to page: #{PAGES.fetch(page)}")
        if page == :content
          GLib::Idle.add { reset_scroll }
        end
        GLib::Idle.add { show_page(PAGES.fetch(page)) }
        false
      end

      def show_page(name)
        main_stack.visible_child_name = name
        false
      end

      def reset_scroll
        main_scroll.vadjustment.value = 0
        false
      end

      def header_sensitive(status)
        title_clamp.sensitive = status
        split_view_toggle_button.sensitive = status
        menu_button.sensitive = status
      end

      # --- WordNet setup ----------------------------------------------------

      # The header is disabled and the spinner shown until the database has
      # been extracted and opened.
      def setup_wordnet
        header_sensitive(false)
        page_switch(:spinner)
        Thread.new do
          Thread.current.name = "database-setup"
          setup_database
        end
      end

      def setup_database
        if DatabaseManager.setup
          GLib::Idle.add { init_wordnet }
        else
          GLib::Idle.add { database_setup_failed }
        end
      rescue StandardError => e
        Utils.log_error("Database setup failed: #{e.message}")
        GLib::Idle.add { database_setup_failed }
      end

      def init_wordnet
        @wordnet = Base.wordnet
        if @wordnet
          complete_initialization
          Base.wordlist(@wordnet) { |wordlist| GLib::Idle.add { wordlist_loaded(wordlist) } }
        else
          database_setup_failed
        end
        false
      end

      def database_setup_failed
        page_switch(:db_error)
        false
      end

      # Sorted the way the completion's binary search expects to find it.
      def wordlist_loaded(wordlist)
        @wordlist = wordlist.sort_by(&:downcase)
        Utils.log_info("Wordlist loaded with #{@wordlist.length} words. Completions now available.")
        false
      end

      def complete_initialization
        header_sensitive(true)
        page_switch(:welcome)
        if @lookup_term.to_s.empty?
          if @settings.auto_paste_on_launch || @auto_paste_requested
            queue_auto_paste
          end
        else
          trigger_search(@lookup_term)
        end
        search_entry.grab_focus_without_selecting
      end

      # --- Entry and completion ---------------------------------------------

      def connect_entry
        @entry_changed_handler = search_entry.signal_connect("changed") { on_entry_changed }
        search_entry.signal_connect("icon-press") { |_entry, position| on_entry_icon_pressed(position) }
      end

      def entry_changed_handler = @entry_changed_handler

      def on_entry_changed
        search_entry.text.then do |text|
          search_entry.secondary_icon_name = clear_icon_name(text)
          completion.update(text)
          if @settings.live_search
            restart_timer(:live_search, LIVE_SEARCH_DELAY) { run_delayed_search }
          end
        end
      end

      def clear_icon_name(text)
        if text.empty?
          ""
        else
          "edit-clear-symbolic"
        end
      end

      # Upstream's _on_entry_icon_clicked calls trigger_search("")
      # (`window.py:491-493`), and trigger_search returns early on blank input,
      # so pressing the clear icon upstream does nothing at all. This port used
      # to empty the entry instead, which is a nicer button and a different
      # app.
      def on_entry_icon_pressed(position)
        if position == Gtk::EntryIconPosition::SECONDARY
          trigger_search("")
        end
      end

      def run_delayed_search
        timers[:live_search] = nil
        on_search_clicked
        false
      end

      def completion_items(text, limit)
        if limit.positive? && !text.strip.empty? && !@wordlist.empty?
          prefix_matches(text, limit)
        else
          []
        end
      end

      # The wordlist is sorted case-insensitively, so the words sharing a
      # prefix are one contiguous run that a binary search finds the start of.
      def prefix_matches(text, limit)
        text.lstrip.then do |typed|
          typed.downcase.then do |needle|
            ranked(candidates(needle), typed, needle).first(limit)
          end
        end
      end

      def candidates(needle)
        (@wordlist.bsearch_index { |word| word.downcase >= needle } || @wordlist.length).then do |start|
          @wordlist[start..].take_while { |word| word.downcase.start_with?(needle) }
        end
      end

      # One entry per spelling, preferring the casing the user is typing, then
      # ordered the way upstream ranks them: fewest spaces in the completed
      # part, then fewest symbols, then shortest, then alphabetically.
      def ranked(words, typed, needle)
        words.group_by(&:downcase)
             .map { |_lower, variants| variants.find { |word| word.start_with?(typed) } || variants.first }
             .sort_by { |word| rank(word, needle) }
      end

      def rank(word, needle)
        word.downcase[needle.length..].to_s.then do |suffix|
          [
            suffix.count(" "),
            suffix.each_char.count { |char| !char.match?(/[[:alnum:]]/) },
            suffix.length,
            word.downcase,
          ]
        end
      end

      # The default widget is the search button whatever this setting says —
      # the blp declares `default-widget: search_button` on the template
      # unconditionally (`window.blp:51`) and build sets it there. Only the
      # button's visibility and the completion popover follow the setting.
      def apply_live_search_visibility
        completion.enabled = !@settings.live_search
        search_button.visible = !@settings.live_search
      end

      # --- Actions ----------------------------------------------------------

      def setup_actions
        WINDOW_ACTIONS.each { |name| window.add_action(action(name)) }
        primary_clipboard.signal_connect("changed") { read_primary_selection }
      end

      def action(name)
        Gio::SimpleAction.new(name).tap do |simple_action|
          simple_action.signal_connect("activate") { activate_action(name) }
          if name == "search-selected"
            simple_action.enabled = false
          end
        end
      end

      def activate_action(name)
        case name
        when "paste-search" then paste_and_search
        when "toggle-sidebar" then split_view_toggle_button.active = !split_view_toggle_button.active?
        when "toggle-menu" then toggle_menu
        when "preferences" then show_preferences
        when "random-word" then search_random_word
        when "search-selected" then trigger_search(@primary_clipboard_text)
        when "toggle-favorites" then sidebar.toggle_favorites_filter
        when "quit" then window.close
        end
      end

      def toggle_menu
        menu_button.grab_focus
        menu_button.active = !menu_button.active?
      end

      def show_preferences
        SettingsDialog.new(self, settings: @settings).tap do |dialog|
          dialog.build
          dialog.present(window)
        end
      end

      def search_random_word
        if @wordlist.empty?
          show_error(_("Wordlist Loading"), _("The word list is still loading. Please try again in a moment."))
        else
          trigger_search(@wordlist.sample)
        end
      end

      def show_error(primary_text, secondary_text)
        ErrorDialog.new(primary_text, secondary_text).present(window)
      end

      # --- Clipboard --------------------------------------------------------

      def paste_and_search
        clipboard.read_text_async(nil) { |source, result| search_clipboard_text(source, result) }
        false
      end

      # Upstream catches `GLib.Error` here (`window.py:260`), which in
      # PyGObject is the one class every GError arrives as. These bindings
      # split GErrors by domain instead, and the error an empty or non-text
      # clipboard raises is `Gio::IOError::NotFound`, which descends from
      # `Gio::Error` and *not* from `GLib::Error` — so the literal translation
      # of upstream's `except GLib.Error` caught nothing and reading an empty
      # clipboard took the whole application down. Found by
      # test/drive_wordbook.rb; FINDINGS.md, defect 11.
      def search_clipboard_text(source, result)
        Base.clean_search_terms(source.read_text_finish(result).to_s).then do |text|
          unless text.strip.empty?
            trigger_search(text)
          end
        end
      rescue GLib::Error, Gio::Error
        nil
      end

      # The primary selection drives the "Search Selected Text" action, which
      # is only enabled while there is a selection to search.
      def read_primary_selection
        primary_clipboard.read_text_async(nil) { |source, result| store_primary_selection(source, result) }
      end

      def store_primary_selection(source, result)
        selection_text(source, result).then do |text|
          @primary_clipboard_text = text
          window.lookup_action("search-selected")&.enabled = !text.nil?
        end
      end

      # Same binding difference as search_clipboard_text above: an empty
      # primary selection raises a Gio::Error, and this runs on every
      # selection change, so it was the likeliest crash in the app.
      def selection_text(source, result)
        source.read_text_finish(result).to_s.then do |text|
          unless text.strip.empty?
            text.gsub("         ", "").delete("\n")
          end
        end
      rescue GLib::Error, Gio::Error
        nil
      end

      def paste_when_active
        if @auto_paste_queued && window.is_active?
          @auto_paste_queued = false
          GLib::Idle.add { paste_and_search }
        end
      end

      # A double click inside a definition searches whatever it selected, when
      # the setting for it is on.
      def double_click_search
        if @settings.double_click
          primary_clipboard.read_text_async(nil) { |source, result| search_clipboard_text(source, result) }
        end
      end

      # --- Keyboard ---------------------------------------------------------

      # Typing a printable character with the entry unfocused appends it to the
      # entry and moves focus there, so a search can be started without
      # reaching for the mouse.
      def quick_search_key(keyval, state)
        Gdk::Keyval.to_unicode(keyval).then do |unicode|
          if typable?(unicode, state)
            append_to_entry([unicode].pack("U"))
          else
            false
          end
        end
      end

      def typable?(unicode, state)
        unicode.positive? &&
          [unicode].pack("U").match?(/[[:graph:]]/) &&
          (state.to_i & SHORTCUT_MASK).zero? &&
          !completion.entry_has_focus?
      end

      def append_to_entry(character)
        search_entry.grab_focus_without_selecting
        "#{search_entry.text}#{character}".then do |text|
          search_entry.text = text
          search_entry.position = text.length
        end
        true
      end

      # --- Pronunciation ----------------------------------------------------

      # espeak-ng is a subprocess, so reading a lemma aloud goes on its own
      # thread and never blocks the window.
      def speak(lemma, ipa)
        @settings.pronunciations_accent.code.then do |accent|
          Thread.new do
            Thread.current.name = "espeak"
            Espeak.read_term(lemma, speed: SPEAK_SPEED, accent: accent, ipa: ipa)
          end
        end
      end

      # --- Timers -----------------------------------------------------------

      def timers = @timers ||= {}

      def restart_timer(name, delay, &block)
        cancel_timer(name)
        timers[name] = GLib::Timeout.add(delay, &block)
      end

      def cancel_timer(name)
        timers[name].then do |id|
          if id
            GLib::Source.remove(id)
            timers[name] = nil
          end
        end
      end

      # --- History ----------------------------------------------------------

      def load_history = sidebar.load(@settings.history)

      def show_undo_toast(message, undo)
        Adwaita::Toast.new(message).tap do |toast|
          toast.button_label = _("Undo")
          toast.signal_connect("button-clicked") { undo.call }
          toast_overlay.add_toast(toast)
        end
      end

      def search_word(word)
        search_entry.signal_handler_block(entry_changed_handler) { search_entry.text = word }
        cancel_timer(:live_search)
        on_search_clicked(text: word)
      end

      def save_state_and_close
        save_state
        false
      end

      # Upstream's _on_exit_clicked is `sys.exit()` (`window.py:537-539`): the
      # process ends without do_shutdown running, so the history and the window
      # size are not written. Quitting the application here instead would run
      # this port's shutdown handler and save them, which is a different thing
      # to press.
      def exit_immediately = exit!(0)

      # A term picked in the sidebar searches it, and on a phone-sized window
      # the sidebar gets out of the way again.
      def activate_history_term(term)
        trigger_search(term)
        if split_view.collapsed?
          split_view.show_sidebar = false
        end
      end

    public

    # --- Memoized widgets ---------------------------------------------------

    # An Adwaita::ApplicationWindow, as upstream's template root is: the
    # constructor takes the application positionally, the content goes in
    # through `content=` rather than `child=`, and it is the window class that
    # can hold the breakpoint below.
    def window
      @window ||= Adwaita::ApplicationWindow.new(@app).tap do |win|
        win.title = _("Wordbook")
        win.icon_name = "accesories-dictionary"
        win.set_default_size(@settings.window_width, @settings.window_height)
        win.set_size_request(MIN_WIDTH, MIN_HEIGHT)
        Gtk::Window.set_default_icon_name(@app.application_id)
        if @development_mode
          win.add_css_class("devel")
        end
      end
    end

    # One setter, the one the blp declares: `main_split_view.collapsed: true`.
    def collapse_breakpoint
      @collapse_breakpoint ||= Adwaita::Breakpoint.new(collapse_condition).tap do |breakpoint|
        breakpoint.add_setter(split_view, "collapsed", true)
      end
    end

    def collapse_condition = @collapse_condition ||= Adwaita::BreakpointCondition.parse(COLLAPSE_CONDITION)

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
    def content_toolbar = @content_toolbar ||= Adwaita::ToolbarView.new
    def key_controller = @key_controller ||= Gtk::EventControllerKey.new
    def clipboard = @clipboard ||= Gdk::Display.default.clipboard
    def primary_clipboard = @primary_clipboard ||= Gdk::Display.default.primary_clipboard

    def split_view
      @split_view ||= Adwaita::OverlaySplitView.new.tap do |view|
        view.min_sidebar_width = 200
        view.max_sidebar_width = 200
      end
    end

    def sidebar
      @sidebar ||= HistorySidebar.new(
        on_activate: method(:activate_history_term),
        on_toast:    method(:show_undo_toast),
        settings:    @settings,
      )
    end

    def definition_view
      @definition_view ||= DefinitionView.new(
        on_search:       method(:search_word),
        on_speak:        method(:speak),
        on_double_click: method(:double_click_search),
        extra_menu:      definition_extra_menu,
      )
    end

    def completion
      @completion ||= SearchCompletion.new(
        parent:        window,
        entry:         search_entry,
        item_provider: method(:completion_items),
        activate:      method(:trigger_search),
      )
    end

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |header|
        header.centering_policy = :strict
      end
    end

    def title_clamp
      @title_clamp ||= Adwaita::Clamp.new.tap do |clamp|
        clamp.tightening_threshold = 300
      end
    end

    def search_box
      @search_box ||= Gtk::Box.new(:horizontal, 4).tap do |box|
        box.hexpand = true
      end
    end

    def search_entry
      @search_entry ||= Gtk::Entry.new.tap do |entry|
        entry.hexpand = true
        entry.primary_icon_name = "edit-find-symbolic"
        entry.primary_icon_activatable = false
        entry.primary_icon_sensitive = false
        entry.activates_default = true
        entry.secondary_icon_tooltip_text = _("Clear")
      end
    end

    def search_button
      @search_button ||= Utils.accessible("GtkButton", _("Search")).tap do |button|
        button.icon_name = "edit-find-symbolic"
        button.receives_default = true
        button.tooltip_text = _("Search")
        button.add_css_class("suggested-action")
      end
    end

    def split_view_toggle_button
      @split_view_toggle_button ||= Utils.accessible("GtkToggleButton", _("Show History")).tap do |button|
        button.icon_name = "sidebar-show-symbolic"
        button.tooltip_text = _("Show History")
      end
    end

    def menu_button
      @menu_button ||= Utils.accessible("GtkMenuButton", _("Main Menu")).tap do |button|
        button.menu_model = MainMenu.new.build
        button.receives_default = true
        button.direction = :none
        button.tooltip_text = _("Main Menu")
      end
    end

    def main_scroll
      @main_scroll ||= Gtk::ScrolledWindow.new.tap do |scroll|
        scroll.hexpand = true
        scroll.vexpand = true
        scroll.hscrollbar_policy = :never
      end
    end

    def main_clamp
      @main_clamp ||= Adwaita::Clamp.new.tap do |clamp|
        clamp.tightening_threshold = 500
      end
    end

    def main_stack = @main_stack ||= Adwaita::ViewStack.new

    def welcome_page
      @welcome_page ||= Adwaita::StatusPage.new.tap do |page|
        page.icon_name = "dev.mufeed.Wordbook-symbolic"
        page.title = _("Wordbook")
        page.description = _("Look up definitions of any English term")
      end
    end

    def search_fail_page
      @search_fail_page ||= Adwaita::StatusPage.new.tap do |page|
        page.vexpand = true
        page.icon_name = "edit-find-symbolic"
        page.title = _("No definition found")
      end
    end

    def search_fail_description_label
      @search_fail_description_label ||= Gtk::Label.new.tap do |label|
        label.use_markup = true
        label.wrap = true
        label.selectable = true
      end
    end

    def db_error_page
      @db_error_page ||= Adwaita::StatusPage.new.tap do |page|
        page.icon_name = "dialog-error-symbolic"
        page.title = _("Database not found")
        page.description = _("Installation is incomplete. Please reinstall Wordbook.")
      end
    end

    def exit_button
      @exit_button ||= Gtk::Button.new(label: _("Exit")).tap do |button|
        button.add_css_class("pill")
      end
    end

    # Adwaita::Spinner, the widget upstream puts on the page
    # (`data/resources/ui/window.blp:277`). It spins while it is visible
    # without being started.
    def spinner_page = @spinner_page ||= Adwaita::Spinner.new

    # The menu a selection inside a definition gets, so the selected words can
    # be searched without leaving the page.
    def definition_extra_menu
      @definition_extra_menu ||= Gio::Menu.new.tap do |menu|
        menu.append(_("Search Selected Text"), "win.search-selected")
      end
    end

  end
end
