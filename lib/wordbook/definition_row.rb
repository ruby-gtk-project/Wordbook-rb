# frozen_string_literal: true

require "adwaita"

require_relative "relation_box"

module Wordbook
  # DefinitionRow is one numbered definition: the number in its own column, and
  # beside it the definition, the examples WordNet records for it, and a
  # RelationBox per group of related lemmas.
  #
  # Ported from _create_definition_row and _create_definition_separator in
  # upstream's wordbook/window.py.
  #
  # The definition and example labels carry the same "Search Selected Text"
  # extra menu and the same double-click gesture, which is how selecting a word
  # inside a definition and double-clicking it starts a new search.
  #
  class DefinitionRow
    NUMBER_WIDTH = 20

    RELATIONS = [
      ["Synonyms", :syn],
      ["Antonyms", :ant],
      ["Similar to", :sim],
      ["Also see", :also_sees],
    ].freeze

    # Separates consecutive definitions under one header, indented past the
    # number column.
    def self.separator
      Gtk::Separator.new(:horizontal).tap do |separator|
        separator.margin_top = 8
        separator.margin_bottom = 8
        separator.margin_start = 32
      end
    end

    def initialize(synset, number, extra_menu: nil, on_search: nil, on_double_click: nil)
      @synset = synset
      @number = number
      @extra_menu = extra_menu
      @on_search = on_search
      @on_double_click = on_double_click
    end

    def build
      box.tap do |b|
        b.append(number_label)
        b.append(content_box)

        content_box.tap do |content|
          content.append(definition_label)
          example_labels.each { |label| content.append(label) }
          relation_boxes.each { |relation| content.append(relation.build) }
        end
      end
    end

    def box = @box ||= Gtk::Box.new(:horizontal, 12)

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 6).tap do |box|
        box.hexpand = true
      end
    end

    def number_label
      @number_label ||= Gtk::Label.new(@number.to_s).tap do |label|
        label.use_markup = true
        label.valign = :start
        label.margin_top = 2
        label.add_css_class("definition-number")
        label.set_size_request(NUMBER_WIDTH, -1)
      end
    end

    def definition_label = @definition_label ||= searchable_label(@synset[:definition], "definition")

    def example_labels
      @example_labels ||= Array(@synset[:examples]).map { |example| searchable_label(example, "example-text") }
    end

    def relation_boxes
      @relation_boxes ||= RELATIONS.filter_map do |relation_type, key|
        Array(@synset[key]).then do |words|
          unless words.empty?
            RelationBox.new(relation_type, words, on_search: @on_search)
          end
        end
      end
    end

    private

      def searchable_label(text, css_class)
        Gtk::Label.new(text.to_s).tap do |label|
          label.wrap = true
          label.xalign = 0.0
          label.selectable = true
          label.add_css_class(css_class)
          if @extra_menu
            label.extra_menu = @extra_menu
          end
          label.add_controller(double_click_gesture)
        end
      end

      # Upstream splits the detection across "pressed" (was this the second
      # click?) and "stopped" (the click sequence is over, act on it), so a
      # double click on a selected word searches it rather than extending the
      # selection.
      def double_click_gesture
        Gtk::GestureClick.new.tap do |gesture|
          gesture.signal_connect("pressed") { |_g, n_press, _x, _y| @doubled = n_press == 2 }
          gesture.signal_connect("stopped") do
            if @doubled
              @on_double_click&.call
            end
          end
        end
      end
  end
end
