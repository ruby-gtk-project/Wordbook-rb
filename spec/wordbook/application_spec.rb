# frozen_string_literal: true

require "wordbook/application"

RSpec.describe Wordbook::Application do
  # allocate rather than new: the constructor creates the config and data
  # directories, and the option parser these examples are about does not touch
  # any instance state.
  def parse(*arguments) = described_class.allocate.send(:parse, arguments)

  describe "the command line" do
    it "is empty for no arguments" do
      expect(parse).to eq({})
    end

    it "reads --look-up's term from the next argument" do
      expect(parse("--look-up", "dictionary")).to eq({look_up: "dictionary"})
    end

    it "reads --look-up's term from the same argument after an =" do
      expect(parse("--look-up=dictionary")).to eq({look_up: "dictionary"})
    end

    it "reads the short form the same way" do
      expect(parse("-l", "dictionary")).to eq({look_up: "dictionary"})
      expect(parse("-l=dictionary")).to eq({look_up: "dictionary"})
    end

    it "reports a --look-up with no term rather than searching for nothing" do
      parse("--look-up").then do |options|
        expect(options[:look_up]).to be_nil
        expect(options[:error]).to eq("Missing argument for --look-up")
      end
    end

    it "treats a term spelled like a flag as a term" do
      # GOption consumes the argument after --look-up whatever it looks like.
      expect(parse("--look-up", "-i")).to eq({look_up: "-i"})
      expect(parse("--look-up", "--verbose")).to eq({look_up: "--verbose"})
    end

    it "reads the three switches, long and short" do
      expect(parse("--info")).to eq({info: true})
      expect(parse("-i")).to eq({info: true})
      expect(parse("--verbose")).to eq({verbose: true})
      expect(parse("-v")).to eq({verbose: true})
      expect(parse("--auto-paste")).to eq({auto_paste: true})
      expect(parse("-p")).to eq({auto_paste: true})
    end

    it "reads several options together" do
      parse(
        "-v",
        "--look-up",
        "cat",
        "--auto-paste",
      ).then { |options| expect(options).to eq({verbose: true, look_up: "cat", auto_paste: true}) }
    end

    it "ignores a positional argument, as upstream's options dict does" do
      expect(parse("cat")).to eq({})
      expect(parse("cat", "--info")).to eq({info: true})
    end

    it "keeps the last --look-up when the option is repeated" do
      parse(
        "--look-up",
        "cat",
        "--look-up",
        "dog",
      ).then { |options| expect(options).to eq({look_up: "dog"}) }
    end
  end

  describe "the accelerator table" do
    it "binds every accelerator the shortcuts dialog shows" do
      %w[
        app.shortcuts
        win.preferences
        win.paste-search
        win.random-word
        win.search-selected
        win.toggle-sidebar
        win.toggle-menu
        win.quit
      ].each do |action|
        expect(described_class::APP_ACCELS[action]).not_to be_nil, "#{action} has no accelerator"
      end
    end

    it "binds upstream's accelerators unchanged" do
      expect(described_class::APP_ACCELS).to include(
        "app.quit"            => ["<Primary>q"],
        "win.quit"            => ["<Primary>w"],
        "win.search-selected" => ["<Primary>s"],
        "win.random-word"     => ["<Primary>r"],
        "win.paste-search"    => ["<Primary><Shift>v"],
        "win.preferences"     => ["<Primary>comma"],
        "win.toggle-sidebar"  => ["F9"],
        "win.toggle-menu"     => ["F10"],
      )
    end

    it "adds one upstream does not bind, and nothing else" do
      # Recorded in COMPONENT_PARITY.md: upstream's main.py binds no
      # accelerator for app.shortcuts.
      %w[
        app.quit
        win.quit
        win.search-selected
        win.random-word
        win.paste-search
        win.preferences
        win.toggle-sidebar
        win.toggle-menu
      ].then { |upstream| expect(described_class::APP_ACCELS.keys - upstream).to eq(["app.shortcuts"]) }
    end
  end
end
