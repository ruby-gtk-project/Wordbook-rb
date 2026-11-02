# frozen_string_literal: true

require "adwaita"

require_relative "history_object"
require_relative "history_row"
require_relative "settings"

module Wordbook
  # HistorySidebar is the sidebar pane: a header with a favourites filter and a
  # clear button, and below it either the list of searched terms or a status
  # page saying there are none.
  #
  # Ported from the `sidebar` half of upstream's data/resources/ui/window.blp
  # together with the history handling in wordbook/window.py — the list store,
  # the 50-entry cap, the clear-with-undo toast and the favourites filter.
  #
  # Two deliberate differences from upstream's widget tree:
  #
  #   * the filter button is driven by its own `toggled` signal rather than by
  #     a stateful action, and the window's toggle-favorites action flips the
  #     button, so there is one code path and no chance of the action and the
  #     button toggling each other;
  #   * the blp's explicit Viewport is left out, because a GTK4 scrolled window
  #     wraps a non-scrollable child in one itself.
  #
  # The toast belongs to the window's overlay, so clearing reports itself
  # through the on_toast callback rather than showing it here.
  #
  class HistorySidebar
    HISTORY_LIMIT = 50

    def initialize(on_activate:, on_toast:, settings: Settings.get)
      @on_activate = on_activate
      @on_toast = on_toast
      @settings = settings
      @favorites_only = false
      @rows = {}
    end

    def build
      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = stack

        header_bar.tap do |header|
          header.title_widget = window_title
          header.pack_start(favorites_filter_button)
          header.pack_end(clear_history_button)

          favorites_filter_button.signal_connect("toggled") { |button| apply_favorites_only(button.active?) }
          clear_history_button.signal_connect("clicked") { clear_history }
        end

        stack.tap do |view_stack|
          view_stack.add_named(scroller, "list")
          view_stack.add_named(empty_page, "empty")

          scroller.tap do |window|
            window.child = listbox

            listbox.tap do |list|
              list.bind_model(store) { |item| row_for(item).build }
              list.signal_connect("row-activated") { |_list, row| activate_row(row) }
            end
          end
        end

        store.signal_connect("items-changed") do |_store, position, _removed, added|
          if added.positive?
            GLib::Idle.add { style_new_rows(position, added) }
          end
        end
      end.tap { update_clear_button_sensitivity }
    end

    # The terms remembered from the last run, each carrying the favourite flag
    # the settings recorded for it.
    def load(terms)
      store.splice(0, 0, terms.map { |term| HistoryObject.new(term, favorite: @settings.favorite?(term)) })
      update_clear_button_sensitivity
    end

    def terms = items.map(&:term)
    def favorites_only? = @favorites_only

    # Upstream's _add_to_history: a term already in the list moves back to the
    # top rather than appearing twice, and the oldest entries fall off the end.
    def add(term)
      index_of(term).then do |existing|
        if existing
          store.remove(existing)
        end
      end
      store.insert(0, HistoryObject.new(term, favorite: @settings.favorite?(term)))
      while store.n_items > HISTORY_LIMIT
        store.remove(store.n_items - 1)
      end
      update_clear_button_sensitivity
    end

    # Favourited terms survive a clear; everything else goes, with one toast
    # offering to put it all back.
    def clear_history
      removable.then do |removals|
        unless removals.empty?
          removals.reverse_each { |index, _item| store.remove(index) }
          update_clear_button_sensitivity
          @on_toast.call("History cleared", -> { restore(removals) })
        end
      end
    end

    def restore(removals)
      removals.each { |index, item| store.insert(index, item) }
      update_clear_button_sensitivity
    end

    # What the window's toggle-favorites action does: the button's own toggled
    # handler is what applies the filter.
    def toggle_favorites_filter = favorites_filter_button.active = !favorites_filter_button.active?

    # Upstream's _on_favorite_toggled: the flag, the settings and the row's
    # star and background all move together.
    def toggle_favorite(item)
      item.favorite = !item.favorite?
      if item.favorite?
        @settings.add_favorite(item.term)
      else
        @settings.remove_favorite(item.term)
      end
      @rows[item.term]&.refresh
      apply_visuals_to(index_of(item.term), item)
    end

    # Memoized widgets

    def store = @store ||= Gio::ListStore.new(HistoryObject)
    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    # Adwaita::WindowTitle takes its title and subtitle positionally, like
    # NavigationPage and Toast do.
    def window_title = @window_title ||= Adwaita::WindowTitle.new("History", "")

    def stack
      @stack ||= Adwaita::ViewStack.new.tap do |view_stack|
        view_stack.vexpand = true
      end
    end

    def scroller
      @scroller ||= Gtk::ScrolledWindow.new.tap do |window|
        window.hscrollbar_policy = :never
        window.has_frame = false
      end
    end

    def listbox
      @listbox ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.add_css_class("navigation-sidebar")
      end
    end

    def favorites_filter_button
      @favorites_filter_button ||= Gtk::ToggleButton.new.tap do |button|
        button.icon_name = HistoryRow::UNSTARRED
        button.tooltip_text = "Show Favorites Only"
        button.add_css_class("flat")
      end
    end

    def clear_history_button
      @clear_history_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "user-trash-symbolic"
        button.tooltip_text = "Clear History"
        button.sensitive = false
        button.add_css_class("flat")
      end
    end

    def empty_page
      @empty_page ||= Adwaita::StatusPage.new.tap do |page|
        page.icon_name = "document-open-recent-symbolic"
        page.title = "No recent searches or favorites"
        page.add_css_class("compact")
      end
    end

    private

      def items = (0...store.n_items).map { |index| store.get_item(index) }

      def apply_favorites_only(enabled)
        @favorites_only = enabled
        favorites_filter_button.icon_name = filter_icon_name
        apply_visuals_to_all
      end

      # Looked up by term rather than by object identity: the terms are unique
      # because `add` moves a repeated search instead of appending it.
      def index_of(term) = (0...store.n_items).find { |index| store.get_item(index).term == term }

      def removable
        (0...store.n_items).filter_map do |index|
          store.get_item(index).then do |item|
            unless item.favorite?
              [index, item]
            end
          end
        end
      end

      def row_for(item)
        HistoryRow.new(item, on_toggle_favorite: method(:toggle_favorite)).tap do |row|
          @rows[item.term] = row
        end
      end

      def activate_row(row)
        store.get_item(row.index).then do |item|
          if item
            @on_activate.call(item.term)
          end
        end
      end

      # The rows only exist once the list box has built them, which is why
      # upstream styles freshly added ones from an idle callback.
      def style_new_rows(position, added)
        (position...(position + added)).each do |index|
          apply_visuals_to(index, store.get_item(index))
        end
        false
      end

      def apply_visuals_to(index, item)
        if index && item
          listbox.get_row_at_index(index).then do |row|
            if row
              HistoryRow.apply_visuals(row, item, favorites_only: @favorites_only)
            end
          end
        end
      end

      def apply_visuals_to_all
        (0...store.n_items).each { |index| apply_visuals_to(index, store.get_item(index)) }
      end

      # Nothing to clear means a disabled button and the empty status page.
      def update_clear_button_sensitivity
        store.n_items.positive?.then do |has_history|
          clear_history_button.sensitive = has_history
          if has_history
            stack.visible_child_name = "list"
          else
            stack.visible_child_name = "empty"
          end
        end
      end

      def filter_icon_name
        if @favorites_only
          HistoryRow::STARRED
        else
          HistoryRow::UNSTARRED
        end
      end
  end
end
