# frozen_string_literal: true

require "wordbook/translations"

# The catalogue is upstream's, and the port's job is to ask it for exactly the
# keys it holds. These examples compare the markers in lib/ against po/de.po:
# a msgid reworded by one byte, a context dropped from a p_ call, or a new
# string added without a catalogue entry all show up here rather than as
# English text in fifteen languages.
RSpec.describe Wordbook::Translations do
  ROOT = File.expand_path("../..", __dir__)

  # The keys the port adds, which upstream does not have and no language has
  # been offered. Recorded in TRANSLATION_PARITY.md; listed here so that a key
  # added without being recorded fails this spec.
  ADDED_KEYS = [
    [nil, "Did you mean: %s?"],
    [nil, "Ruby Port"],
  ].freeze

  MARKER = /
    (?<![A-Za-z0-9_])(?<marker>N_|_|p_)\(\s*
    (?<first>"(?:[^"\\]|\\.)*")
    (?:\s*,\s*(?<second>"(?:[^"\\]|\\.)*"))?
  /x

  def self.unquote(literal) = literal[1..-2].gsub('\\"', '"').gsub("\\n", "\n").gsub("\\\\", "\\")

  # Every (msgctxt, msgid) the port asks for, from the marker calls in lib/.
  def self.marked_keys
    Dir.glob(File.join(ROOT, "lib/**/*.rb")).flat_map do |file|
      File.read(file).to_enum(:scan, MARKER).map { Regexp.last_match }.map do |match|
        if match[:marker] == "p_"
          [unquote(match[:first]), unquote(match[:second])]
        else
          [nil, unquote(match[:first])]
        end
      end
    end.uniq
  end

  # Every (msgctxt, msgid) the catalogue holds, parsed out of the .po so the
  # comparison is against the file the translations actually live in.
  def self.catalogue_keys(path)
    File.read(path).split("\n\n").filter_map do |block|
      block.match(/^msgid\s+((?:"(?:[^"\\]|\\.)*"\s*)+)/m).then do |ids|
        if ids
          [
            block.match(/^msgctxt\s+"((?:[^"\\]|\\.)*)"/m)&.captures&.first,
            ids.captures.first.scan(/"((?:[^"\\]|\\.)*)"/).flatten.join.then { |id| unquote(%("#{id}")) },
          ]
        end
      end
    end.reject { |_context, id| id.empty? }
  end

  MARKED = marked_keys
  CATALOGUE = catalogue_keys(File.join(ROOT, "po/de.po"))

  it "asks for every message upstream's catalogue holds" do
    expect(CATALOGUE - MARKED).to eq([])
  end

  it "asks for nothing the catalogue does not hold, beyond the recorded additions" do
    expect(MARKED - CATALOGUE).to match_array(ADDED_KEYS)
  end

  it "covers all fifteen of upstream's languages" do
    File.read(File.join(ROOT, "po/LINGUAS")).split.then do |languages|
      expect(languages.length).to eq(15)
      expect(languages.map { |lang| File.exist?(File.join(ROOT, "po/#{lang}.po")) }).to all(be(true))
    end
  end

  it "holds the same message set in every language" do
    File.read(File.join(ROOT, "po/LINGUAS")).split.each do |language|
      expect(self.class.catalogue_keys(File.join(ROOT, "po/#{language}.po")))
        .to match_array(CATALOGUE), "#{language}.po has a different message set"
    end
  end

  it "lists the port's own files in POTFILES, not upstream's" do
    File.read(File.join(ROOT, "po/POTFILES")).split.then do |listed|
      expect(listed).to all(satisfy { |path| File.exist?(File.join(ROOT, path)) })
      expect(listed).to include("data/dev.mufeed.Wordbook.desktop.in")
      expect(listed).to include("data/dev.mufeed.Wordbook.metainfo.xml.in")
      expect(listed.grep(/\.blp$|\.py$/)).to eq([])
    end
  end

  it "keeps upstream's domain, because the domain is the .mo filename" do
    expect(described_class::TEXT_DOMAIN).to eq("wordbook")
  end

  describe "a class that includes it" do
    let(:includer) { Class.new { include Wordbook::Translations }.new }

    it "can translate" do
      expect(includer._("Clear History")).to be_a(String)
    end

    it "distinguishes a context-carrying key from the plain one" do
      # Upstream has both `_("_Preferences")` (the menu item) and
      # `C_("shortcut window", "Preferences")` (the shortcuts row), and every
      # language translates them separately.
      expect(includer.p_("shortcut window", "Preferences"))
        .not_to eq(includer._("_Preferences"))
    end
  end
end
