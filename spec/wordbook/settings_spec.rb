# frozen_string_literal: true

require "json"
require "tmpdir"

require "wordbook/settings"

RSpec.describe Wordbook::Settings do
  around do |example|
    Dir.mktmpdir("wordbook-settings") do |dir|
      @path = File.join(dir, "wordbook.json")
      example.run
    end
  end

  def settings = described_class.new(path: @path)
  def written = JSON.parse(File.read(@path))

  describe "loading" do
    it "writes the defaults when there is no file yet" do
      settings.then do |store|
        expect(store.live_search).to be(true)
        expect(store.double_click).to be(false)
        expect(store.pronunciations_accent.code).to eq("us")
        expect(store.window_width).to eq(400)
        expect(store.window_height).to eq(600)
      end
      expect(written.keys).to contain_exactly("behavior", "appearance", "state")
    end

    it "reads a file back" do
      File.write(@path, JSON.dump("behavior" => {"live_search" => false}))
      expect(settings.live_search).to be(false)
    end

    it "falls back to the defaults for a missing key and a missing section" do
      File.write(@path, JSON.dump("behavior" => {"double_click" => true}))
      settings.then do |store|
        expect(store.double_click).to be(true)
        expect(store.live_search).to be(true)
        expect(store.window_width).to eq(400)
      end
    end

    it "ignores a section it does not know and a section that is not a hash" do
      File.write(@path, JSON.dump("behavior" => ["nonsense"], "nonsense" => {"a" => 1}))
      expect(settings.live_search).to be(true)
    end

    it "falls back to the defaults for a file that is not JSON at all" do
      File.write(@path, "{ not json")
      expect(settings.live_search).to be(true)
    end
  end

  describe "validation" do
    it "replaces an accent code it does not know with us, as pydantic does upstream" do
      File.write(@path, JSON.dump("behavior" => {"pronunciations_accent" => "au"}))
      expect(settings.pronunciations_accent.code).to eq("us")
    end

    it "keeps an accent code it knows" do
      File.write(@path, JSON.dump("behavior" => {"pronunciations_accent" => "gb"}))
      expect(settings.pronunciations_accent.code).to eq("gb")
    end

    it "truncates a stored history to the last HISTORY_LIMIT entries" do
      File.write(@path, JSON.dump("state" => {"history" => (1..30).map(&:to_s)}))
      settings.history.then do |history|
        expect(history.length).to eq(described_class::HISTORY_LIMIT)
        expect(history.first).to eq("11")
        expect(history.last).to eq("30")
      end
    end

    it "stringifies whatever the history held" do
      File.write(@path, JSON.dump("state" => {"history" => [1, 2.5, nil]}))
      expect(settings.history).to eq(["1", "2.5", ""])
    end
  end

  describe "writing" do
    it "saves on every property write" do
      settings.tap { |store| store.live_search = false }
      expect(written["behavior"]["live_search"]).to be(false)
    end

    it "coerces a truthy value to a boolean" do
      settings.tap { |store| store.double_click = "yes" }.then do |store|
        expect(store.double_click).to be(false)
      end
    end

    it "returns a copy of the history, so a caller cannot mutate the store" do
      settings.tap { |store| store.history = ["cat"] }.then do |store|
        store.history << "dog"
        expect(store.history).to eq(["cat"])
      end
    end

    it "adds and removes favourites without duplicating them" do
      settings.tap do |store|
        store.add_favorite("cat")
        store.add_favorite("cat")
        expect(store.favorites).to eq(["cat"])
        expect(store.favorite?("cat")).to be(true)
        store.remove_favorite("cat")
        expect(store.favorites).to eq([])
        expect(store.favorite?("cat")).to be(false)
      end
    end
  end

  describe "#batch_update" do
    it "applies several settings and writes the file once" do
      settings.then do |store|
        expect(store).to receive(:save).once.and_call_original
        store.batch_update(
          "history"       => %w[cat dog],
          "window_width"  => 900,
          "window_height" => 700,
        )
      end
      written.then do |data|
        expect(data["state"]["history"]).to eq(%w[cat dog])
        expect(data["state"]["window_width"]).to eq(900)
        expect(data["state"]["window_height"]).to eq(700)
      end
    end

    it "warns about a key that names no setting and applies the rest" do
      expect(Wordbook::Utils).to receive(:log_warning).with(/unknown setting: nonsense/)
      settings.tap { |store| store.batch_update("nonsense" => 1, "window_width" => 800) }.then do |store|
        expect(store.window_width).to eq(800)
      end
    end

    it "restores autosaving even when an update raises" do
      settings.then do |store|
        allow(store).to receive(:window_width=).and_raise(ArgumentError)
        expect { store.batch_update("window_width" => 1) }.to raise_error(ArgumentError)
        store.window_height = 123
        expect(written["state"]["window_height"]).to eq(123)
      end
    end
  end

  describe "#reset_to_defaults" do
    it "puts every section back and writes it" do
      settings.tap do |store|
        store.live_search = false
        store.add_favorite("cat")
        store.reset_to_defaults
        expect(store.live_search).to be(true)
        expect(store.favorites).to eq([])
      end
      expect(written["behavior"]["live_search"]).to be(true)
    end
  end

  describe Wordbook::PronunciationAccent do
    it "indexes the accents in the order the combo row lists them" do
      expect(described_class.display_names).to eq(["American English", "British English"])
      expect(described_class.from_index(1).code).to eq("gb")
      expect(described_class::GB.index).to eq(1)
    end

    it "falls back to us for an index or a code it does not know" do
      expect(described_class.from_index(9).code).to eq("us")
      expect(described_class.from_code("au").code).to eq("us")
    end
  end
end
