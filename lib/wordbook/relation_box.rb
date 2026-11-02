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

    # Adwaita::WrapBox is what upstream uses (`wordbook/window.py:1072`), and
    # what lets the chips reflow onto as many lines as they need. It arrived in
    # libadwaita 1.7, so where the bindings predate it a Gtk::FlowBox is built
    # instead. I do not know whether the two reflow the same way, because this
    # branch has never been on screen: Gtk::FlowBox allocates homogeneous rows
    # by default and `max_children_per_line` set to the word count is my guess
    # at the same layout, not a measurement. FINDINGS.md, defect 5, is why
    # there is no screenshot.
    def wrap_box = @wrap_box ||= new_wrap_box

    def new_wrap_box
      if Adwaita.const_defined?(:WrapBox)
        Adwaita::WrapBox.new.tap do |box|
          box.valign = :start
          box.line_spacing = LINE_SPACING
          box.child_spacing = CHILD_SPACING
        end
      else
        Gtk::FlowBox.new.tap do |box|
          box.valign = :start
          box.selection_mode = :none
          box.homogeneous = false
          box.row_spacing = LINE_SPACING
          box.column_spacing = CHILD_SPACING
          box.max_children_per_line = @words.length + 1
        end
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
