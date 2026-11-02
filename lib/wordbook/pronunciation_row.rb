# frozen_string_literal: true

require "adwaita"

require_relative "translations"

module Wordbook
  # PronunciationRow is the header above a block of definitions: the lemma,
  # then its IPA dimmed next to it, then a button that reads it aloud.
  #
  # Ported from _create_header_row and _append_pronunciation_controls in
  # upstream's wordbook/window.py. A lemma with no pronunciation gets the label
  # alone, which is what upstream's early return leaves behind.
  #
  # A pronunciation espeak-ng derived from the spelling (`fallback?`) is read
  # aloud as text rather than as phonemes: feeding a guessed transcription back
  # to espeak-ng as phonemes would compound the guess.
  #
  class PronunciationRow
    include Translations

    SPEAK_ICON = "audio-volume-high-symbolic"

    def initialize(lemma, pronunciation, label_text: nil, css_class: "synset-header", on_speak: nil)
      @lemma = lemma
      @pronunciation = pronunciation
      @label_text = label_text || lemma
      @css_class = css_class
      @on_speak = on_speak
    end

    def build
      box.tap do |b|
        b.append(header_label)

        if pronounceable?
          b.append(ipa_label)
          b.append(controls_box)

          controls_box.tap do |controls|
            controls.append(play_button)

            play_button.signal_connect("clicked") { @on_speak&.call(@lemma, spoken_ipa) }
          end
        end
      end
    end

    def pronounceable? = !@pronunciation.nil? && !@pronunciation.ipa.to_s.empty?

    def spoken_ipa
      if @pronunciation.fallback?
        nil
      else
        @pronunciation.ipa
      end
    end

    def box
      @box ||= Gtk::Box.new(:horizontal, 4).tap do |b|
        b.valign = :center
      end
    end

    def header_label
      @header_label ||= Gtk::Label.new(@label_text).tap do |label|
        label.use_markup = true
        label.xalign = 0.0
        label.hexpand = true
        label.selectable = true
        label.add_css_class(@css_class)
      end
    end

    def ipa_label
      @ipa_label ||= Gtk::Label.new(@pronunciation.ipa).tap do |label|
        label.selectable = true
        label.valign = :center
        label.add_css_class("dimmed")
      end
    end

    def controls_box
      @controls_box ||= Gtk::Box.new(:horizontal, 2).tap do |box|
        box.valign = :center
      end
    end

    def play_button
      @play_button ||= Gtk::Button.new(icon_name: SPEAK_ICON).tap do |button|
        button.valign = :center
        button.tooltip_text = _("Listen to Pronunciation")
        button.add_css_class("flat")
        button.add_css_class("circular")
      end
    end
  end
end
