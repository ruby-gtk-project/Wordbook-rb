# frozen_string_literal: true

require "tmpdir"

require "wordbook/base"
require "wordbook/database_builder"

# The builder is checked by reading what it wrote with the app's own reader:
# DatabaseBuilder and Base::Wordnet are the two halves of one schema, and a
# column renamed on one side is only a defect because the other side asks for
# it by name.
RSpec.describe Wordbook::DatabaseBuilder do
  def lexicon_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE LexicalResource SYSTEM "http://globalwordnet.github.io/schemas/WN-LMF-1.3.dtd">
      <LexicalResource xmlns:dc="https://globalwordnet.github.io/schemas/dc/">
        <Lexicon id="oewn" label="Open English Wordnet" language="en" version="2025+">
          <LexicalEntry id="oewn-word-n">
            <Lemma writtenForm="word" partOfSpeech="n">
              <Pronunciation variety="US">ˈwɜɹd</Pronunciation>
              <Pronunciation variety="GB">wəːd</Pronunciation>
            </Lemma>
            <Form writtenForm="words"/>
            <Sense id="oewn-word__1.10.00.." synset="oewn-06297048-n">
              <SenseRelation relType="antonym" target="oewn-silence__1.10.00.."/>
            </Sense>
            <Sense id="oewn-word__2.32.00.." synset="oewn-00900000-v"/>
          </LexicalEntry>
          <LexicalEntry id="oewn-term-n">
            <Lemma writtenForm="term" partOfSpeech="n"/>
            <Sense id="oewn-term__1.10.00.." synset="oewn-06297048-n"/>
          </LexicalEntry>
          <LexicalEntry id="oewn-silence-n">
            <Lemma writtenForm="silence" partOfSpeech="n"/>
            <Sense id="oewn-silence__1.10.00.." synset="oewn-07000000-n"/>
          </LexicalEntry>
          <LexicalEntry id="oewn-wordbook-n">
            <Lemma writtenForm="wordbook" partOfSpeech="n"/>
            <Sense id="oewn-wordbook__1.10.00.." synset="oewn-06300000-n"/>
          </LexicalEntry>
          <Synset id="oewn-06297048-n" ili="i80334" members="oewn-word-n oewn-term-n" partOfSpeech="n">
            <Definition>a unit of language that native speakers can identify</Definition>
            <ILIDefinition>not the app's definition</ILIDefinition>
            <Example>he said a word in my ear</Example>
            <Example>mark my words</Example>
            <SynsetRelation relType="similar" target="oewn-06300000-n"/>
            <SynsetRelation relType="also" target="oewn-07000000-n"/>
          </Synset>
          <Synset id="oewn-00900000-v" ili="i1" members="oewn-word-n" partOfSpeech="v">
            <Definition>to express in words</Definition>
          </Synset>
          <Synset id="oewn-07000000-n" ili="i2" members="oewn-silence-n" partOfSpeech="n">
            <Definition>the absence of sound</Definition>
          </Synset>
          <Synset id="oewn-06300000-n" ili="i3" members="oewn-wordbook-n" partOfSpeech="n">
            <Definition>a book of words</Definition>
          </Synset>
        </Lexicon>
      </LexicalResource>
    XML
  end

  around do |example|
    Dir.mktmpdir("wordbook-builder") do |dir|
      @dir = dir
      example.run
    end
  end

  before do
    File.write(source, lexicon_xml)
    described_class.new(source: source, output: archive, compression_level: 1).tap(&:build)
    system(
      "zstd",
      "-q",
      "-d",
      "-f",
      "-o",
      database,
      archive,
      out: File::NULL,
    )
  end

  def source = File.join(@dir, "lexicon.xml")
  def archive = File.join(@dir, "wn-spec.db.zst")
  def database = File.join(@dir, "wn.db")

  def wordnet = @wordnet ||= Wordbook::Base::Wordnet.open(path: database, specifier: "oewn:2025+")

  after { @wordnet&.close }

  describe "the archive" do
    it "writes a zstd archive the database manager can unpack" do
      expect(File.size(archive)).to be_positive
    end

    it "names its default output after the WordNet file version the app looks for" do
      expect(described_class.default_output)
        .to eq("data/wn-#{Wordbook::Constants::WN_FILE_VERSION}.db.zst")
    end

    it "refuses a compression level zstd does not have" do
      expect { described_class.new(source: source, compression_level: 23) }
        .to raise_error(ArgumentError, /outside/)
    end
  end

  describe "the lexicon" do
    it "records the specifier as <id>:<version>, which is what the app opens it by" do
      expect(wordnet).not_to be_nil
      expect(wordnet.specifier).to eq("oewn:2025+")
    end

    it "counts what it read" do
      described_class.new(source: source, output: archive, compression_level: 1).tap(&:build).then do |builder|
        expect(builder.counts).to eq({ entries: 4, senses: 5, synsets: 4 })
        expect(builder.specifiers).to eq(["oewn:2025+"])
      end
    end

    it "lists every lemma for the completion popover and the random-word action" do
      expect(wordnet.lemmas.sort).to eq(["silence", "term", "word", "wordbook"])
    end
  end

  describe "a synset" do
    def noun = wordnet.synsets("word").find { |synset| synset.pos == "n" }

    it "carries the part of speech, the definition and the examples" do
      expect(noun.definition).to eq("a unit of language that native speakers can identify")
      expect(noun.examples).to eq(["he said a word in my ear", "mark my words"])
    end

    it "ignores the interlingual definition, which the app never shows" do
      expect(noun.definition).not_to include("not the app's definition")
    end

    it "lists its members as lemmas" do
      expect(noun.lemmas).to eq(["word", "term"])
    end

    it "is found through a non-lemma form of its entry" do
      expect(wordnet.synsets("words").map(&:pos)).to eq(["n", "v"])
    end

    it "is found through a differently cased search term" do
      expect(wordnet.synsets("word".upcase.downcase).length).to eq(2)
    end
  end

  describe "the pronunciations" do
    it "hangs them off the lemma, keyed by it, with the variety as written" do
      wordnet.synsets("word").first.pronunciations.then do |by_lemma|
        expect(by_lemma.keys).to eq(["word"])
        expect(by_lemma["word"]).to eq(
          [{ value: "ˈwɜɹd", variety: "US" }, { value: "wəːd", variety: "GB" }],
        )
      end
    end

    it "lets the accent the user chose pick one" do
      Wordbook::Base.get_definition("word", wordnet, accent: "gb").then do |data|
        expect(data[:result]["noun"].first[:pronunciation].ipa).to eq("wəːd")
      end
    end
  end

  describe "the relations" do
    def noun = wordnet.synsets("word").find { |synset| synset.pos == "n" }

    # The antonym is a SenseRelation whose target is a sense id defined later
    # in the document than the relation is, which is what the pending tables
    # exist to resolve.
    it "resolves an antonym recorded between senses" do
      expect(noun.antonyms).to eq(["silence"])
    end

    it "resolves the two synset relations the app draws chips for" do
      expect(noun.similar).to eq(["wordbook"])
      expect(noun.also).to eq(["silence"])
    end

    it "leaves relation kinds the app does not ask for out of its results" do
      expect(Wordbook::Base.related_lemmas(noun, "word").keys).to eq([:syn, :ant, :sim, :also_sees])
    end
  end
end
