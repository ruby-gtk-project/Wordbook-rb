# frozen_string_literal: true

require "gtk4"

module Wordbook
  # MainMenu is the model behind the header bar's menu button.
  #
  # A port of the `menu app-menu` block in upstream's
  # data/resources/ui/window.blp: a search section and a help section, with the
  # same labels, mnemonics and action names.
  #
  class MainMenu
    SEARCH_SECTION = [
      ["Paste & Search", "win.paste-search"],
      ["Search Selected Text", "win.search-selected"],
      ["_Random Word", "win.random-word"],
    ].freeze

    HELP_SECTION = [
      ["_Preferences", "win.preferences"],
      ["_Keyboard Shortcuts", "app.shortcuts"],
      ["_About Wordbook", "app.about"],
    ].freeze

    def build
      menu.tap do |model|
        model.append_section(nil, section(SEARCH_SECTION))
        model.append_section(nil, section(HELP_SECTION))
      end
    end

    def menu = @menu ||= Gio::Menu.new

    private

      def section(items)
        Gio::Menu.new.tap do |model|
          items.each { |label, action| model.append(label, action) }
        end
      end
  end
end
