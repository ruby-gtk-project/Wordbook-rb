# frozen_string_literal: true

require "wordbook/espeak"

RSpec.describe Wordbook::Espeak do
  describe ".ipa_to_espeak" do
    it "wraps the result in the double brackets espeak-ng reads as phonemes" do
      expect(described_class.ipa_to_espeak("kat")).to eq("[[kat]]")
    end

    it "strips the slashes and brackets a transcription is quoted in" do
      expect(described_class.ipa_to_espeak("/kat/")).to eq("[[kat]]")
      expect(described_class.ipa_to_espeak("[kat]")).to eq("[[kat]]")
    end

    it "converts the stress marks and the length mark" do
      expect(described_class.ipa_to_espeak("ˈdɪkʃəˌnɛri")).to eq("[['dIkS@,nEri]]")
    end

    it "prefers the longest symbol, so a digraph is not split" do
      # "tʃ" is one key and "ʃ" another; the digraph has to win or "tʃ" would
      # come out as "tS" via the single symbol and lose the affricate.
      expect(described_class.ipa_to_espeak("tʃeɪn")).to eq("[[tSeIn]]")
    end

    it "converts the vowel length pairs" do
      expect(described_class.ipa_to_espeak("biːt")).to eq("[[bi:t]]")
      expect(described_class.ipa_to_espeak("bɔːt")).to eq("[[bO:t]]")
    end

    it "drops the syllable and linking marks" do
      expect(described_class.ipa_to_espeak("dɪk.ʃə‿nɛ|ri‖")).to eq("[[dIkS@nEri]]")
    end

    it "drops anything still outside ASCII after the substitutions" do
      expect(described_class.ipa_to_espeak("kaʡt")).to eq("[[kat]]")
    end

    it "leaves an empty transcription as an empty phoneme block" do
      expect(described_class.ipa_to_espeak("")).to eq("[[]]")
    end
  end

  describe ".phoneme_input" do
    it "hands espeak-ng the text itself when there is no transcription" do
      expect(described_class.phoneme_input("cat", nil)).to eq("cat")
      expect(described_class.phoneme_input("cat", "")).to eq("cat")
    end

    it "hands over converted phonemes when there is one" do
      expect(described_class.phoneme_input("cat", "kæt")).to eq("[[kat]]")
    end
  end

  describe ".version_failure_message" do
    it "reports a missing binary differently from a binary that failed" do
      expect(described_class.version_failure_message(nil))
        .to eq("Dependency missing: espeak-ng is not installed or not in PATH.")
      expect(described_class.version_failure_message(1))
        .to eq("Could not retrieve espeak-ng version information.")
    end
  end
end
