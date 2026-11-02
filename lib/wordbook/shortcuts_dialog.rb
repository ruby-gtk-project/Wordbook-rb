# frozen_string_literal: true

require "adwaita"

require_relative "translations"

module Wordbook
  # ShortcutsDialog lists the keyboard shortcuts.
  #
  # A port of upstream's data/resources/ui/shortcuts-dialog.blp, which is an
  # Adw.ShortcutsDialog with one "General" section.
  #
  # Upstream's items carry an `action-name` and let Adwaita resolve whatever
  # accelerator the application bound to it. I could not do that here:
  # Adwaita::ShortcutsItem.new takes its title and accelerator positionally and
  # the binding offers no way to set `action-name` (FINDINGS.md, defect 3). So
  # each row names its action and the accelerator is read out of the same table
  # the application installs its accelerators from — the table is passed in
  # rather than re-typed here, so a rebound shortcut cannot start disagreeing
  # with what this dialog shows.
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

    def initialize(accels)
      super()
      @accels = accels
    end

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

      def item(label, action) = Adwaita::ShortcutsItem.new(label, accelerator_for(action))

      # A row whose action has no accelerator would be built with an empty
      # string, which Adwaita renders as a blank key. Every row has one today;
      # if that stops being true, the accel table is what has to change.
      def accelerator_for(action) = Array(@accels[action]).first.to_s
  end
end
