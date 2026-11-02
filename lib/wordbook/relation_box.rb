# frozen_string_literal: true

require "adwaita"

module Wordbook
  # RelationBox shows one group of related lemmas — synonyms, antonyms,
  # "similar to" or "also see" — as a label followed by a button per word, each
  # of which searches that word.
  #
  # Ported from _create_relation_widget in upstream's wordbook/window.py.
  #
  class RelationBox
    LINE_SPACING = 4
    CHILD_SPACING = 6

    def initialize(relation_type, words, on_search:)
      @relation_type = relation_type
      @words = words
      @on_search = on_search
    end

    def build
      wrap_box.tap do |box|
        box.append(type_label)
        @words.each { |word| box.append(word_button(word)) }
      end
    end

    # Adwaita::WrapBox, the widget upstream builds (`wordbook/window.py:1073`),
    # with upstream's `valign`, `line_spacing` and `child_spacing`. It reflows
    # the chips onto as many lines as they need.
    def wrap_box
      @wrap_box ||= Adwaita::WrapBox.new.tap do |box|
        box.valign = :start
        box.line_spacing = LINE_SPACING
        box.child_spacing = CHILD_SPACING
      end
    end

    def type_label
      @type_label ||= Gtk::Label.new("#{@relation_type}:").tap do |label|
        label.xalign = 0.0
        label.valign = :center
        label.add_css_class("relation-type")
      end
    end

    def word_button(word)
      Gtk::Button.new(label: word).tap do |button|
        button.add_css_class("lemma-button")
        button.signal_connect("clicked") { @on_search.call(word) }
      end
    end
  end
end
