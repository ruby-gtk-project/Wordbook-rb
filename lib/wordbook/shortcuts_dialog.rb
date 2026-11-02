# frozen_string_literal: true

require "adwaita"

module Wordbook
  # ShortcutsDialog lists the keyboard shortcuts.
  #
  # A port of upstream's data/resources/ui/shortcuts-dialog.blp, which is an
  # Adw.ShortcutsDialog with one "General" section. Upstream's items name an
  # action and let Adwaita look its accelerator up; the Ruby ShortcutsItem is
  # constructed with the accelerator itself, so the accelerators below are the
  # ones the application binds in wordbook/main.py — plus one for the shortcuts
  # window itself, which upstream's main.py leaves unbound.
  #
  class ShortcutsDialog < Adwaita::ShortcutsDialog
    SECTIONS = {
      "General" => [
        ["Show Shortcuts", "<Control>question"],
        ["Preferences", "<Control>comma"],
        ["Paste and Search", "<Control><Shift>v"],
        ["Random Word", "<Control>r"],
        ["Search Selected Text", "<Control>s"],
        ["Toggle Sidebar", "F9"],
        ["Show Menu", "F10"],
        ["Quit", "<Control>w"],
      ],
    }.freeze

    def initialize
      super()
      self.title = "Keyboard Shortcuts"
    end

    def build
      tap do |dialog|
        SECTIONS.each { |title, items| dialog.add(section(title, items)) }
      end
    end

    private

      def section(title, items)
        Adwaita::ShortcutsSection.new.tap do |section|
          section.title = title
          items.each { |label, accelerator| section.add(item(label, accelerator)) }
        end
      end

      # Positional, not keyword, arguments — even though the error a
      # no-argument new raises advertises the signature as
      # "title: utf8, accelerator: utf8".
      def item(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)
  end
end
