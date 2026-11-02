# frozen_string_literal: true

require "adwaita"

require_relative "settings"

module Wordbook
  # SettingsDialog is the preferences dialog: one appearance switch and the
  # four behaviour settings.
  #
  # Ported from upstream's data/resources/ui/settings-window.blp and
  # wordbook/settings_window.py. Each row writes its setting as it is flipped —
  # the Settings store saves itself — and the two that change the window as
  # well (live search hides the search button, the accent re-renders the
  # pronunciations) call back into it.
  #
  class SettingsDialog < Adwaita::PreferencesDialog
    CONTENT_WIDTH = 450
    CONTENT_HEIGHT = 350

    def initialize(parent, settings: Settings.get)
      super()
      @parent = parent
      @settings = settings
      self.title = "Preferences"
      self.content_width = CONTENT_WIDTH
      self.content_height = CONTENT_HEIGHT
    end

    def build
      tap do |dialog|
        dialog.add(preferences_page)

        preferences_page.tap do |page|
          page.add(appearance_group)
          page.add(behavior_group)

          appearance_group.add(dark_ui_switch)
          behavior_group.tap do |group|
            group.add(live_search_switch)
            group.add(double_click_switch)
            group.add(auto_paste_switch)
            group.add(pronunciations_accent_row)
          end
        end

        load_settings

        dark_ui_switch.signal_connect("notify::active") { apply_dark_ui }
        live_search_switch.signal_connect("notify::active") { apply_live_search }
        double_click_switch.signal_connect("notify::active") { @settings.double_click = double_click_switch.active? }
        auto_paste_switch.signal_connect("notify::active") do
          @settings.auto_paste_on_launch = auto_paste_switch.active?
        end
        pronunciations_accent_row.signal_connect("notify::selected") { apply_accent }
      end
    end

    # The rows start from the stored settings, before the handlers above are
    # connected, so loading them does not write them straight back.
    def load_settings
      double_click_switch.active = @settings.double_click
      live_search_switch.active = @settings.live_search
      auto_paste_switch.active = @settings.auto_paste_on_launch
      dark_ui_switch.active = @settings.gtk_dark_ui
      pronunciations_accent_row.selected = @settings.pronunciations_accent.index
    end

    # Memoized widgets

    def preferences_page = @preferences_page ||= Adwaita::PreferencesPage.new

    def appearance_group
      @appearance_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Appearance"
      end
    end

    def behavior_group
      @behavior_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Behavior"
      end
    end

    def dark_ui_switch
      @dark_ui_switch ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = "Force Dark Mode"
      end
    end

    def live_search_switch
      @live_search_switch ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = "Live Search"
        row.subtitle = "Show definition as the terms are typed in"
      end
    end

    def double_click_switch
      @double_click_switch ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = "Double Click Search"
        row.subtitle = "Search any word by double clicking on it"
      end
    end

    def auto_paste_switch
      @auto_paste_switch ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = "Auto Paste on Launch"
        row.subtitle = "Automatically paste and search clipboard content on launch"
      end
    end

    def pronunciations_accent_row
      @pronunciations_accent_row ||= Adwaita::ComboRow.new.tap do |row|
        row.title = "Pronunciations Accent"
        row.model = Gtk::StringList.new(PronunciationAccent.display_names)
      end
    end

    private

      def apply_dark_ui
        @settings.gtk_dark_ui = dark_ui_switch.active?
        Adwaita::StyleManager.default.color_scheme = color_scheme
      end

      def color_scheme
        if dark_ui_switch.active?
          Adwaita::ColorScheme::FORCE_DARK
        else
          Adwaita::ColorScheme::DEFAULT
        end
      end

      # With live search on there is nothing to press, so the search button
      # goes away and the completion popover takes over; with it off the button
      # comes back and becomes the window's default widget again.
      def apply_live_search
        live_search_switch.active?.then do |enabled|
          @parent.completion_enabled = !enabled
          @parent.search_button.visible = !enabled
          unless enabled
            @parent.default_widget = @parent.search_button
          end
          @settings.live_search = enabled
        end
      end

      # Re-rendering the current page is what makes the new accent audible and
      # visible immediately; it deliberately does not touch the history.
      def apply_accent
        PronunciationAccent.from_index(pronunciations_accent_row.selected).then do |accent|
          unless accent == @settings.pronunciations_accent
            @settings.pronunciations_accent = accent
            @parent.refresh_current_search_pronunciations
          end
        end
      end
  end
end
