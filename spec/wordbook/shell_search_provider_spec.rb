# frozen_string_literal: true

require "wordbook/shell_search_provider"

RSpec.describe Wordbook::ShellSearchProvider do
  subject(:provider) { described_class.new(binary: "wordbook-under-test", wordnet: wordnet) }

  let(:wordnet) { instance_double("Wordbook::Base::Wordnet") }

  # What Base.get_definition returns: the POS names it keys by, each holding
  # the synsets for that part of speech.
  def definition_for(term)
    {
      term:   term,
      result: {
        "noun"      => [
          {name: term, definition: "the first noun sense"},
          {name: term, definition: "the second noun sense"},
        ],
        "verb"      => [{name: term, definition: "the verb sense"}],
        "adjective" => [],
      },
    }
  end

  before do
    allow(Wordbook::Base).to receive(:get_definition) { |term, _wn| definition_for(term) }
  end

  describe "#initial_result_set" do
    it "reports one result per part of speech that has a synset" do
      expect(provider.initial_result_set(["cat"]).length).to eq(2)
    end

    it "looks each term up on its own" do
      expect(provider.initial_result_set(%w[cat dog]).length).to eq(4)
    end

    it "forgets the previous search's results" do
      provider.initial_result_set(["cat"])
      provider.initial_result_set(["dog"]).then do |ids|
        expect(provider.result_metas(ids).map { |meta| meta["name"] }).to all(eq("dog"))
      end
    end

    it "reports nothing for a term with no definition" do
      allow(Wordbook::Base).to receive(:get_definition).and_return({term: "zzz", result: nil})
      expect(provider.initial_result_set(["zzz"])).to eq([])
    end

    it "survives a lookup that raises, because the database may not be there yet" do
      allow(Wordbook::Base).to receive(:get_definition).and_raise(RuntimeError, "no database")
      allow(provider).to receive(:warn)
      expect(provider.initial_result_set(["cat"])).to eq([])
    end
  end

  describe "#subsearch_result_set" do
    it "searches the narrowed terms afresh, ignoring the previous results" do
      expect(provider.subsearch_result_set(["ignored"], ["cat"]).length).to eq(2)
    end
  end

  describe "#result_metas" do
    it "reports the lemma as the id, the name and the definition as the description" do
      provider.initial_result_set(["cat"]).then do |ids|
        provider.result_metas([ids.first]).then do |metas|
          expect(metas.length).to eq(1)
          expect(metas.first).to eq(
            "id"          => "cat",
            "name"        => "cat",
            "description" => "the first noun sense",
          )
        end
      end
    end

    it "skips an identifier it does not know" do
      provider.initial_result_set(["cat"])
      expect(provider.result_metas(["nothing-like-an-id"])).to eq([])
    end

    it "reports the first synset of each part of speech, not every synset" do
      provider.initial_result_set(["cat"]).then do |ids|
        expect(provider.result_metas(ids).map { |meta| meta["description"] })
          .to contain_exactly("the first noun sense", "the verb sense")
      end
    end
  end

  describe "#activate_result" do
    it "opens the app on the term, detached" do
      expect(Process).to receive(:spawn).with("wordbook-under-test", "--look-up", "cat").and_return(4321)
      expect(Process).to receive(:detach).with(4321)
      provider.initial_result_set(["cat"]).then do |ids|
        provider.activate_result(ids.first, [], 0)
      end
    end

    it "accepts the lemma itself as the identifier, which is what the shell hands back" do
      expect(Process).to receive(:spawn).with("wordbook-under-test", "--look-up", "cat").and_return(1)
      allow(Process).to receive(:detach)
      provider.activate_result("cat", [], 0)
    end

    it "reports a launcher that is not there rather than raising" do
      allow(Process).to receive(:spawn).and_raise(Errno::ENOENT)
      expect(Wordbook::Utils).to receive(:log_error).with(/Could not launch wordbook-under-test/)
      expect(provider.activate_result("cat", [], 0)).to be_nil
    end
  end

  describe "#launch_search" do
    it "opens the app with no arguments" do
      expect(Process).to receive(:spawn).with("wordbook-under-test").and_return(99)
      expect(Process).to receive(:detach).with(99)
      provider.launch_search(["cat"], 0)
    end
  end

  describe "the D-Bus interface" do
    it "describes the five methods org.gnome.Shell.SearchProvider2 requires" do
      %w[
        GetInitialResultSet
        GetSubsearchResultSet
        GetResultMetas
        ActivateResult
        LaunchSearch
      ].each { |name| expect(described_class::NODE_XML).to include(%(name="#{name}")) }
    end

    # The .ini is a template, as upstream's is: meson substitutes @APP_ID@ and
    # @object_path@ from the profile (data/meson.build:88-110), and here
    # flake.nix and `rake install:data` do. So the comparison is between what
    # the Ruby resolves for a profile and what the substitution would write.
    it "owns the bus name and object path the search provider .ini points at" do
      expect(described_class::BUS_NAME).to eq("dev.mufeed.Wordbook.SearchProvider")
      expect(described_class::OBJECT_PATH).to eq("/dev/mufeed/Wordbook/SearchProvider")
      File.read(File.expand_path("../../data/dev.mufeed.Wordbook.SearchProvider.ini", __dir__))
          .gsub("@APP_ID@", Wordbook::Profile.app_id)
          .gsub("@object_path@", Wordbook::Profile.object_path)
          .then do |ini|
        expect(ini).to include("BusName=#{described_class::BUS_NAME}")
        expect(ini).to include("ObjectPath=#{described_class::OBJECT_PATH}")
      end
    end

    it "moves the bus name and the object path with the profile, as upstream's meson does" do
      expect(Wordbook::Profile.bus_name).to eq("dev.mufeed.Wordbook.SearchProvider")
      expect(Wordbook::Profile.object_path).to eq("/dev/mufeed/Wordbook/SearchProvider")

      # The profile is read from the environment because this port has no
      # configure step; upstream reads it from `-Dprofile=development`.
      original = ENV.fetch("WORDBOOK_PROFILE", nil)
      ENV["WORDBOOK_PROFILE"] = "development"
      expect(Wordbook::Profile.app_id).to eq("dev.mufeed.Wordbook.Devel")
      expect(Wordbook::Profile.bus_name).to eq("dev.mufeed.Wordbook.Devel.SearchProvider")
      expect(Wordbook::Profile.object_path).to eq("/dev/mufeed/Wordbook/Devel/SearchProvider")
      ENV["WORDBOOK_PROFILE"] = original
    end
  end
end
