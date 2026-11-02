# frozen_string_literal: true

require "tmpdir"
require "zlib"

require "wordbook/lmf_reader"

RSpec.describe Wordbook::LmfReader do
  around do |example|
    Dir.mktmpdir("wordbook-lmf") do |dir|
      @dir = dir
      example.run
    end
  end

  def write(name, content)
    File.join(@dir, name).tap { |path| File.binwrite(path, content) }
  end

  def write_gz(name, content)
    File.join(@dir, name).tap do |path|
      Zlib::GzipWriter.open(path) { |gz| gz.write(content) }
    end
  end

  def events_of(path)
    [].tap do |collected|
      described_class.open(path) do |reader|
        reader.each { |kind, name, payload| collected << [kind, name, payload] }
      end
    end
  end

  describe "the events" do
    it "yields a start and an end for every element, in document order" do
      write("one.xml", <<~XML).then do |path|
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE LexicalResource SYSTEM "http://globalwordnet.github.io/schemas/WN-LMF-1.3.dtd">
        <LexicalResource>
          <Lexicon id="oewn" version="2025+">
            <Synset id="oewn-1-n" partOfSpeech="n">
              <Definition>a unit of language</Definition>
            </Synset>
          </Lexicon>
        </LexicalResource>
      XML
        expect(events_of(path).map { |kind, name, _| [kind, name] }).to eq(
          [
            [:start, "LexicalResource"],
            [:start, "Lexicon"],
            [:start, "Synset"],
            [:start, "Definition"],
            [:end, "Definition"],
            [:end, "Synset"],
            [:end, "Lexicon"],
            [:end, "LexicalResource"],
          ],
        )
      end
    end

    it "yields both events for an empty element" do
      write("empty.xml", %(<Lexicon><Sense id="a" synset="b"/></Lexicon>)).then do |path|
        expect(events_of(path)).to eq(
          [
            [:start, "Lexicon", {}],
            [:start, "Sense", { "id" => "a", "synset" => "b" }],
            [:end, "Sense", ""],
            [:end, "Lexicon", ""],
          ],
        )
      end
    end

    it "carries an element's character data on its end event" do
      write("text.xml", "<Synset><Example>mark my words</Example></Synset>").then do |path|
        expect(events_of(path).assoc(:end).last).to eq("mark my words")
      end
    end
  end

  describe "the attributes" do
    it "reads every attribute of a start tag" do
      write("attrs.xml", %(<Lexicon id="oewn" label="Open English Wordnet" version="2025+"/>)).then do |path|
        expect(events_of(path).first.last).to eq(
          { "id" => "oewn", "label" => "Open English Wordnet", "version" => "2025+" },
        )
      end
    end

    it "reads a namespaced attribute name" do
      write("ns.xml", %(<SenseRelation relType="other" dc:type="agent"/>)).then do |path|
        expect(events_of(path).first.last["dc:type"]).to eq("agent")
      end
    end
  end

  describe "the entities" do
    it "resolves the five XML entities in attributes and in text" do
      write("ents.xml", <<~XML).then do |path|
        <Lexicon>
          <Lemma writtenForm="&amp;-sign &gt; &lt;&quot;&apos;x&apos;&quot;"/>
          <Definition>rock &amp; roll</Definition>
        </Lexicon>
      XML
        events_of(path).then do |events|
          expect(events.assoc(:start)[2]).to eq({})
          expect(events[1].last["writtenForm"]).to eq(%(&-sign > <"'x'"))
          expect(events.select { |kind, name, _| kind == :end && name == "Definition" }.first.last)
            .to eq("rock & roll")
        end
      end
    end

    it "resolves decimal and hexadecimal character references" do
      write("refs.xml", "<Definition>&#119;&#x6F;rd</Definition>").then do |path|
        expect(events_of(path).assoc(:end).last).to eq("word")
      end
    end

    it "leaves an entity it does not know as it was written" do
      write("unknown.xml", "<Definition>&nbsp;here</Definition>").then do |path|
        expect(events_of(path).assoc(:end).last).to eq("&nbsp;here")
      end
    end
  end

  describe "the stream" do
    it "reads a gzipped lexicon" do
      write_gz("lex.xml.gz", %(<Lexicon id="oewn"/>)).then do |path|
        expect(events_of(path).first).to eq([:start, "Lexicon", { "id" => "oewn" }])
      end
    end

    # The buffer is filled in fixed-size chunks, which land in the middle of
    # multi-byte characters; the IPA below is four of them.
    it "keeps multi-byte characters whole across a read boundary" do
      write("ipa.xml", "<Lexicon>#{"<Pronunciation>ˈwɜɹd</Pronunciation>" * 20_000}</Lexicon>").then do |path|
        events_of(path).select { |kind, name, _| kind == :end && name == "Pronunciation" }.then do |ends|
          expect(ends.length).to eq(20_000)
          expect(ends.map(&:last).uniq).to eq(["ˈwɜɹd"])
        end
      end
    end

    it "finds the end of a tag whose attribute value contains an angle bracket" do
      write("angle.xml", %(<Lemma writtenForm="a>b"/>)).then do |path|
        expect(events_of(path).first.last["writtenForm"]).to eq("a>b")
      end
    end

    it "raises rather than spinning when the document stops inside a tag" do
      write("cut.xml", %(<Lexicon id="oewn"><Synset id="oewn)).then do |path|
        expect { events_of(path) }.to raise_error(
          Wordbook::LmfReader::TruncatedError,
          /document ends inside/,
        )
      end
    end
  end
end
