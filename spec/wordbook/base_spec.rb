# frozen_string_literal: true

require "wordbook/base"

RSpec.describe Wordbook::Base do
  describe ".clean_search_terms" do
    it "leaves an ordinary term alone" do
      expect(described_class.clean_search_terms("dictionary")).to eq("dictionary")
    end

    it "strips the surrounding whitespace" do
      expect(described_class.clean_search_terms("  dictionary \n")).to eq("dictionary")
    end

    it "strips the cleanup characters from both ends" do
      expect(described_class.clean_search_terms('"dictionary?"')).to eq("dictionary")
      expect(described_class.clean_search_terms("-dictionary-")).to eq("dictionary")
      expect(described_class.clean_search_terms("[dictionary];")).to eq("dictionary")
    end

    it "removes the replace characters from inside the term" do
      expect(described_class.clean_search_terms("dic(tion)ary")).to eq("dictionary")
      expect(described_class.clean_search_terms("cat&dog")).to eq("catdog")
      expect(described_class.clean_search_terms("two\nlines")).to eq("twolines")
    end

    it "keeps a hyphen inside a term, where only the ends are stripped" do
      expect(described_class.clean_search_terms("well-being")).to eq("well-being")
    end

    it "cleans away to nothing for input that is only punctuation" do
      expect(described_class.clean_search_terms("???")).to eq("")
      expect(described_class.clean_search_terms(nil)).to eq("")
    end
  end

  describe ".default_process" do
    it "lowercases" do
      expect(described_class.default_process("Dictionary")).to eq("dictionary")
    end

    it "turns every non-alphanumeric character into a space, and does not delete it" do
      expect(described_class.default_process("re-read")).to eq("re read")
      expect(described_class.default_process("ice_cream")).to eq("ice cream")
    end

    it "trims the result" do
      expect(described_class.default_process("  -cat-  ")).to eq("cat")
    end
  end

  describe ".ratio" do
    it "scores an identical pair 100" do
      expect(described_class.ratio("cat", "cat")).to eq(100.0)
    end

    it "scores two empty strings 100, as the ratio of nothing to nothing" do
      expect(described_class.ratio("", "")).to eq(100.0)
    end

    it "scores a disjoint pair 0" do
      expect(described_class.ratio("cat", "bud")).to eq(0.0)
    end

    it "is twice the common subsequence over the combined length" do
      # "cat" vs "cart": common subsequence "cat" is 3, lengths 3 + 4.
      expect(described_class.ratio("cat", "cart")).to be_within(0.01).of(200.0 * 3 / 7)
    end

    it "is case-sensitive, as difflib is" do
      expect(described_class.ratio("Cat", "cat")).to be < 100.0
    end
  end

  describe ".qratio" do
    it "is case-insensitive, as rapidfuzz's QRatio is" do
      expect(described_class.qratio("Cat", "cat")).to eq(100.0)
    end

    it "scores a hyphenated spelling against its spaced spelling as identical" do
      expect(described_class.qratio("re-read", "re read")).to eq(100.0)
    end

    it "does not score a hyphenated spelling against the closed-up spelling as identical" do
      # default_process substitutes a space rather than removing the hyphen, so
      # "re read" and "reread" differ by one character.
      expect(described_class.qratio("re-read", "reread")).to be < 100.0
    end
  end

  describe ".suggestions" do
    let(:wordlist) { %w[cat cart card dictionary dog cast] }

    it "offers nothing for a term of two characters or fewer" do
      expect(described_class.suggestions("ca", wordlist)).to eq([])
    end

    it "offers the closest words, best score first" do
      described_class.suggestions("cart", wordlist).then do |offered|
        expect(offered.map(&:first)).to include("cart", "card", "cast")
        expect(offered.first.first).to eq("cart")
      end
    end

    it "excludes a word scoring exactly the cutoff, because upstream keeps score > 70" do
      # Seven characters in common out of a combined twenty: 200 * 7 / 20 = 70
      # exactly, which is the boundary rapidfuzz's score_cutoff admits and
      # upstream's `if score > 70` then drops.
      expect(described_class.qratio("abcdefg", "abcdefgxyzwvu")).to eq(70.0)
      expect(described_class.suggestions("abcdefg", %w[abcdefgxyzwvu], cutoff: 70).map(&:first)).to eq([])
    end

    it "includes a word scoring above the cutoff" do
      expect(described_class.suggestions("cart", %w[card], cutoff: 70).map(&:first)).to eq(["card"])
    end

    it "offers at most five" do
      expect(described_class.suggestions("cart", %w[cart card cast carts carte cars], limit: 5).length).to eq(5)
    end

    it "breaks a score tie alphabetically" do
      described_class.suggestions("care", %w[card bare], cutoff: 50).then do |offered|
        expect(offered.map(&:first)).to eq(%w[bare card])
      end
    end

    it "ignores the case the word is listed in" do
      expect(described_class.suggestions("cart", %w[CARD], cutoff: 70).map(&:first)).to eq(["CARD"])
    end
  end

  describe ".normalize_lemma" do
    it "turns WordNet's underscores into spaces and trims" do
      expect(described_class.normalize_lemma(" ice_cream ")).to eq("ice cream")
    end
  end

  describe ".find_best_lemma_match" do
    it "prefers an exact match, whatever its case" do
      expect(described_class.find_best_lemma_match("cat", %w[dog Cat cart])).to eq("Cat")
    end

    it "matches an exact term against an underscored lemma" do
      expect(described_class.find_best_lemma_match("ice cream", %w[ice_cream])).to eq("ice cream")
    end

    it "falls back to the closest lemma above the cutoff" do
      # "cart" shares four characters with "carte" out of a combined nine:
      # 200 * 4 / 9 = 88.9, above the 80 difflib's cutoff=0.8 sets.
      expect(described_class.find_best_lemma_match("carte", %w[zebra cart])).to eq("cart")
    end

    it "falls back to the first lemma when nothing is close enough" do
      expect(described_class.find_best_lemma_match("cart", %w[zebra mongoose])).to eq("zebra")
    end
  end

  describe ".group_synsets_by_lemma" do
    def pronunciation(ipa, fallback: false) = described_class::PronunciationInfo.of(ipa, fallback: fallback)

    it "groups by lemma, then by pronunciation, keeping the order they arrived in" do
      [
        {name: "bass", pronunciation: pronunciation("beɪs"), definition: "a low voice"},
        {name: "bass", pronunciation: pronunciation("bæs"), definition: "a fish"},
        {name: "bass", pronunciation: pronunciation("beɪs"), definition: "a low range"},
        {name: "treble", pronunciation: nil, definition: "a high voice"},
      ].then do |synsets|
        described_class.group_synsets_by_lemma(synsets).then do |groups|
          expect(groups.map(&:lemma)).to eq(%w[bass treble])
          expect(groups.first.pronunciation_groups.length).to eq(2)
          expect(groups.first.pronunciation_groups.first.pronunciation.ipa).to eq("beɪs")
          expect(groups.first.pronunciation_groups.first.synsets.length).to eq(2)
          expect(groups.first.pronunciation_groups.last.synsets.length).to eq(1)
          expect(groups.last.pronunciation_groups.first.pronunciation).to be_nil
        end
      end
    end

    it "separates a WordNet pronunciation from an espeak-ng fallback with the same IPA" do
      [
        {name: "cat", pronunciation: pronunciation("kæt")},
        {name: "cat", pronunciation: pronunciation("kæt", fallback: true)},
      ].then do |synsets|
        expect(described_class.group_synsets_by_lemma(synsets).first.pronunciation_groups.length).to eq(2)
      end
    end
  end

  describe ".pick_pronunciation" do
    it "prefers the variety the user asked for" do
      [{value: "kæt", variety: "us"}, {value: "kat", variety: "gb"}].then do |available|
        expect(described_class.pick_pronunciation(available, "gb").ipa).to eq("kat")
      end
    end

    it "falls back to the first one WordNet lists" do
      [{value: "kæt", variety: nil}, {value: "kat", variety: "gb"}].then do |available|
        expect(described_class.pick_pronunciation(available, "au").ipa).to eq("kæt")
      end
    end

    it "ignores an empty transcription" do
      expect(described_class.pick_pronunciation([{value: "", variety: "us"}], "us")).to be_nil
    end

    it "is nil when there is nothing to pick" do
      expect(described_class.pick_pronunciation(nil, "us")).to be_nil
    end
  end

  describe ".related_lemmas" do
    it "drops the matched lemma and the duplicates from every relation" do
      described_class::Synset.new(
        pos:            "n",
        lemmas:         %w[cat Cat feline],
        definition:     "a small animal",
        examples:       [],
        pronunciations: {},
        antonyms:       %w[dog dog],
        similar:        %w[cat lynx],
        also:           %w[cat],
      ).then do |synset|
        described_class.related_lemmas(synset, "cat").then do |related|
          expect(related[:syn]).to eq(["feline"])
          expect(related[:ant]).to eq(["dog"])
          expect(related[:sim]).to eq(["lynx"])
          expect(related[:also_sees]).to eq([])
        end
      end
    end
  end
end
