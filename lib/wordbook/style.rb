# frozen_string_literal: true

require "gtk4"

module Wordbook
  # Style carries the application stylesheet and installs it on the display.
  #
  # A port of upstream's data/resources/style.css, which meson compiles into
  # the gresource bundle the application loads from its resource base path.
  # This port has no resource bundle, so the same rules are a string loaded
  # into a Gtk::CssProvider at startup — the class names the widgets add
  # (history-item, favorite-item, pos-header, synset-header, definition,
  # definition-number, example-text, relation-type, lemma-button and the
  # completion popover's) are the ones these rules style.
  #
  module Style
    CSS = <<~'CSS'
      /* History items styling */
      .history-item {
          padding-left: 4px;
          padding-right: 4px;
      }

      /* Favorite items styling */
      .favorite-item {
          background-color: color-mix(in srgb, var(--accent-color) 10%, transparent);
      }

      .favorite-item:hover {
          background-color: color-mix(in srgb, var(--accent-color) 15%, transparent);
      }

      /* History list row styling for favorites */
      listbox row.favorite-item {
          background-color: color-mix(in srgb, var(--accent-color) 8%, transparent);
      }

      listbox row.favorite-item:hover {
          background-color: color-mix(in srgb, var(--accent-color) 12%, transparent);
      }

      listbox row.favorite-item:selected {
          background-color: color-mix(in srgb, var(--accent-color) 20%, transparent);
      }

      .example-text {
          font-style: italic;
          color: var(--accent-color);
      }

      .pos-header {
          font-size: large;
          font-weight: bold;
      }

      .relation-type,
      .definition-number,
      .synset-header {
          font-weight: bold;
      }

      .definition {
          font-size: large;
      }

      /* Lemma buttons (eg: synonym buttons) */
      .lemma-button {
          padding-left: 6px;
          padding-right: 6px;
          padding-top: 1px;
          padding-bottom: 1px;
          color: var(--accent-fg-color);
          background-color: var(--accent-bg-color);
      }

      .lemma-button:hover {
          background-color: color-mix(in srgb, var(--accent-bg-color) 70%, transparent);
      }

      entry.completion-entry {
          transition:
              border-bottom-left-radius 120ms cubic-bezier(0.2, 0, 0, 1),
              border-bottom-right-radius 120ms cubic-bezier(0.2, 0, 0, 1);
      }

      entry.completion-entry.completion-active {
          border-bottom-left-radius: 0;
          border-bottom-right-radius: 0;
      }

      popover.completion-popover.background > contents {
          padding: 0;
          border-top-width: 0;
          border-top-left-radius: 0;
          border-top-right-radius: 0;
      }

      popover.completion-popover scrolledwindow,
      popover.completion-popover viewport,
      popover.completion-popover list {
          background: transparent;
      }

      popover.completion-popover list row {
          min-height: 0;
          padding: 0;
          border-radius: 0;
      }

      popover.completion-popover list row:hover {
          background-color: color-mix(in srgb, currentColor 6%, transparent);
      }

      popover.completion-popover list row:selected {
          background-color: color-mix(in srgb, currentColor 10%, transparent);
          color: inherit;
      }
    CSS

    # Installed at application priority, so these rules win over the Adwaita
    # stylesheet without overriding a user stylesheet.
    def self.install(display = Gdk::Display.default)
      if display
        Gtk::CssProvider.new.tap do |provider|
          provider.load(data: CSS)
          Gtk::StyleContext.add_provider_for_display(
            display,
            provider,
            Gtk::StyleProvider::PRIORITY_APPLICATION,
          )
        end
      end
    end
  end
end
