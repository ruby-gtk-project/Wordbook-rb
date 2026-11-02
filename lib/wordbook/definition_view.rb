# frozen_string_literal: true

require "adwaita"

require_relative "base"
require_relative "definition_row"
require_relative "pronunciation_row"

module Wordbook
  # DefinitionView is the content page: one boxed-list row per part of speech,
  # each holding the lemma headers and the numbered definitions under them.
  #
  # Ported from _populate_definitions and _create_definition_widget in
  # upstream's wordbook/window.py, plus the definitions_listbox the blp
  # declares.
  #
  class DefinitionView
    def initialize(on_search:, on_speak:, on_double_click: nil, extra_menu: nil)
      @on_search = on_search
      @on_speak = on_speak
      @on_double_click = on_double_click
      @extra_menu = extra_menu
    end

    def build = listbox

    # Every part of speech that has synsets becomes a row; the rest of the
    # result hash is skipped, which is why an all-empty result never reaches
    # here (the window shows its "No definition found" page instead).
    def populate(result)
      clear
      result.each do |pos, synsets|
        unless synsets.empty?
          append_row(pos_widget(pos, synsets))
        end
      end
    end

    def clear
      while listbox.first_child
        listbox.remove(listbox.first_child)
      end
    end

    def listbox
      @listbox ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.show_separators = false
        list.vexpand = true
        list.margin_start = 12
        list.margin_end = 12
        list.margin_top = 8
        list.margin_bottom = 12
        list.add_css_class("boxed-list-separate")
      end
    end

    private

      # Appending is what gives a row the "activatable" class, so it is taken
      # off again afterwards — these rows are not clickable, as upstream notes.
      def append_row(widget)
        definition_row_container(widget).tap do |row|
          listbox.append(row)
          row.remove_css_class("activatable")
        end
      end

      def definition_row_container(widget)
        Gtk::ListBoxRow.new.tap do |row|
          row.focusable = false
          row.margin_top = 4
          row.margin_bottom = 4
          row.margin_start = 4
          row.margin_end = 4
          row.child = widget
        end
      end

      def pos_widget(pos, synsets)
        Gtk::Box.new(:vertical, 12).tap do |box|
          box.margin_top = 12
          box.margin_bottom = 12
          box.margin_start = 12
          box.margin_end = 12
          box.append(pos_label(pos))
          Base.group_synsets_by_lemma(synsets).each { |group| box.append(lemma_box(group)) }
        end
      end

      def pos_label(pos)
        Gtk::Label.new(pos).tap do |label|
          label.xalign = 0.0
          label.use_markup = true
          label.selectable = true
          label.add_css_class("pos-header")
        end
      end

      # One lemma, with a block per pronunciation it has: a lemma recorded with
      # both an American and a British IPA gets a header for each, and the
      # definitions that carry that pronunciation under it.
      def lemma_box(lemma_group)
        Gtk::Box.new(:vertical, 8).tap do |box|
          lemma_group.pronunciation_groups.each do |group|
            box.append(pronunciation_box(lemma_group.lemma, group))
          end
        end
      end

      def pronunciation_box(lemma, group)
        Gtk::Box.new(:vertical, 4).tap do |box|
          box.append(header_row(lemma, group.pronunciation).build)
          group.synsets.each_with_index do |synset, index|
            box.append(definition_row(synset, index + 1).build)
            if index + 1 < group.synsets.length
              box.append(DefinitionRow.separator)
            end
          end
        end
      end

      def header_row(lemma, pronunciation)
        PronunciationRow.new(
          lemma,
          pronunciation,
          css_class: "synset-header",
          on_speak:  @on_speak,
        )
      end

      def definition_row(synset, number)
        DefinitionRow.new(
          synset,
          number,
          extra_menu:      @extra_menu,
          on_search:       @on_search,
          on_double_click: @on_double_click,
        )
      end
  end
end
