# frozen_string_literal: true

require "gtk4"

require_relative "translations"

module Wordbook
  # MainMenu is the model behind the header bar's menu button.
  #
  # A port of the `menu app-menu` block in upstream's
  # data/resources/ui/window.blp: a search section and a help section, with the
  # same labels, mnemonics and action names.
  #
  # The labels are marked with N_ in the tables and looked up with _() when the
  # menu is built, so the catalogue is read after the locale is settled rather
  # than while this file is being loaded. The mnemonic underscores are inside
  # the msgid, as upstream has them, because a translator picks a mnemonic that
  # works in their own language.
  #
  class MainMenu
    include Translations

    SEARCH_SECTION = [
      [N_("Paste & Search"), "win.paste-search"],
      [N_("Search Selected Text"), "win.search-selected"],
      [N_("_Random Word"), "win.random-word"],
    ].freeze

    HELP_SECTION = [
      [N_("_Preferences"), "win.preferences"],
      [N_("_Keyboard Shortcuts"), "app.shortcuts"],
      [N_("_About Wordbook"), "app.about"],
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
          items.each { |label, action| model.append(_(label), action) }
        end
      end
  end
end
