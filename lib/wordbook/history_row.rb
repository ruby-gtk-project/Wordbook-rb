# frozen_string_literal: true

require "adwaita"

require_relative "history_object"
require_relative "translations"

module Wordbook
  # HistoryRow is a row in the history sidebar: the term, ellipsized, and a
  # star button that favourites it.
  #
  # Ported from _create_history_label and _update_row_visuals in upstream's
  # wordbook/window.py. The visuals belong to the Gtk::ListBoxRow the list box
  # wraps this widget in rather than to the widget itself, so applying them is
  # a class method the sidebar calls with the row it got from the list box;
  # upstream reaches the row with get_ancestor instead.
  #
  class HistoryRow
    include Translations

    STARRED = "starred-symbolic"
    UNSTARRED = "non-starred-symbolic"

    # The row is styled for every item, and the favourites filter hides the
    # rest by making them invisible — the same trick upstream uses, so the
    # store never has to be re-filtered.
    def self.apply_visuals(row, item, favorites_only:)
      row.tap do |list_row|
        list_row.add_css_class("history-item")
        if item.favorite?
          list_row.add_css_class("favorite-item")
        else
          list_row.remove_css_class("favorite-item")
        end
        list_row.visible = !favorites_only || item.favorite?
      end
    end

    attr_reader :item

    def initialize(item, on_toggle_favorite:)
      @item = item
      @on_toggle_favorite = on_toggle_favorite
    end

    def build
      box.tap do |b|
        b.append(content_box)
        b.append(favorite_button)

        content_box.tap do |content|
          content.append(term_label)
        end

        favorite_button.tap do |button|
          button.signal_connect("clicked") { @on_toggle_favorite.call(@item) }
        end
      end
    end

    # Called after the item's favourite flag has been flipped, so the star
    # reflects it without the row being rebuilt.
    def refresh = favorite_button.icon_name = icon_name

    def icon_name
      if @item.favorite?
        STARRED
      else
        UNSTARRED
      end
    end

    def box
      @box ||= Gtk::Box.new(:horizontal, 8).tap do |b|
        b.visible = true
      end
    end

    def content_box
      @content_box ||= Gtk::Box.new(:horizontal, 0).tap do |content|
        content.visible = true
        content.hexpand = true
        content.tooltip_text = @item.term
      end
    end

    def term_label
      @term_label ||= Gtk::Label.new(@item.term).tap do |label|
        label.ellipsize = :end
        label.halign = :start
        label.margin_top = 8
        label.margin_bottom = 8
        label.margin_start = 8
        label.margin_end = 8
      end
    end

    def favorite_button
      @favorite_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = icon_name
        button.tooltip_text = _("Toggle Favorite")
        button.valign = :center
        button.margin_top = 4
        button.margin_bottom = 4
        button.add_css_class("flat")
        button.add_css_class("circular")
      end
    end
  end
end
