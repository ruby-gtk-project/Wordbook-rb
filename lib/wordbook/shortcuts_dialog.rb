# frozen_string_literal: true

require "adwaita"

require_relative "translations"

module Wordbook
  # ShortcutsDialog lists the keyboard shortcuts.
  #
  # A port of upstream's data/resources/ui/shortcuts-dialog.blp, which is an
  # Adw.ShortcutsDialog with one "General" section.
  #
  # Each item carries the `action-name` upstream's does, and Adwaita resolves
  # the accelerator the application bound to that action — so the dialog cannot
  # show a key the app does not answer. `Adwaita::ShortcutsItem.new` takes its
  # title and accelerator positionally and rejects every keyword form, and the
  # accelerator cannot be left out, so it is built with an empty one and the
  # action name is set after.
  #
  # The labels carry `msgctxt "shortcut window"`, which is what blueprint's
  # C_() produces: `Preferences` with that context and `_Preferences` without
  # it are two different keys, and all fifteen catalogues translate both. They
  # are written out at each `p_` call site, context included, because a context
  # held in a constant is a context no extractor can read: writing
  # `p_(CONTEXT, "Quit")` produced nine context-less keys in this port and left
  # upstream's nine unproduced.
  #
  class ShortcutsDialog < Adwaita::ShortcutsDialog
    include Translations

    def build
      tap do |dialog|
        dialog.add(general_section)
      end
    end

    private

      def general_section
        Adwaita::ShortcutsSection.new.tap do |section|
          section.title = p_("shortcut window", "General")
          general_items.each { |label, action| section.add(item(label, action)) }
        end
      end

      # Upstream's eight rows, in upstream's order.
      def general_items
        [
          [p_("shortcut window", "Show Shortcuts"), "app.shortcuts"],
          [p_("shortcut window", "Preferences"), "win.preferences"],
          [p_("shortcut window", "Paste and Search"), "win.paste-search"],
          [p_("shortcut window", "Random Word"), "win.random-word"],
          [p_("shortcut window", "Search Selected Text"), "win.search-selected"],
          [p_("shortcut window", "Toggle Sidebar"), "win.toggle-sidebar"],
          [p_("shortcut window", "Show Menu"), "win.toggle-menu"],
          [p_("shortcut window", "Quit"), "win.quit"],
        ]
      end

      def item(label, action)
        Adwaita::ShortcutsItem.new(label, "").tap do |shortcut|
          shortcut.action_name = action
        end
      end
  end
end
