# frozen_string_literal: true

require "tmpdir"

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

  # Everything below drives the failure paths. They were 23 of this file's 70
  # lines and nothing in the port had ever entered one of them: upstream
  # degrades silently when espeak-ng is absent, exits non-zero or hangs, and
  # nothing here showed that this port does. A fake espeak-ng on PATH is what
  # makes each one reachable without a real one installed.
  describe "when espeak-ng misbehaves" do
    around do |example|
      Dir.mktmpdir("espeak-stub") do |dir|
        @stub_dir = dir
        original = ENV.fetch("PATH", "")
        ENV["PATH"] = "#{dir}#{File::PATH_SEPARATOR}#{original}"
        described_class.instance_variable_set(:@cache, {})
        example.run
        ENV["PATH"] = original
        described_class.instance_variable_set(:@cache, {})
      end
    end

    # A fake espeak-ng, so PATH decides what the port meets.
    def stub_espeak(body)
      File.join(@stub_dir, Wordbook::Espeak::BINARY).tap do |path|
        File.write(path, "#!/bin/sh\n#{body}\n")
        File.chmod(0o755, path)
      end
    end

    # The binary is not there at all: Open3 raises Errno::ENOENT before the
    # process exists. Upstream logs and carries on with no pronunciation.
    context "with no espeak-ng installed" do
      around do |example|
        original = ENV.fetch("PATH", "")
        ENV["PATH"] = @stub_dir
        example.run
        ENV["PATH"] = original
      end

      it "logs that the command is missing and reports no status" do
        expect(Wordbook::Utils).to receive(:log_error)
          .with("'espeak-ng' command not found. Please install espeak-ng.")
        expect(described_class.run([Wordbook::Espeak::BINARY, "--version"], 5)).to eq([nil, "", ""])
      end

      it "has no pronunciation for a term, rather than raising" do
        allow(Wordbook::Utils).to receive(:log_error)
        expect(described_class.pronunciation("cat")).to be_nil
      end

      it "still prints the app banner, and says the dependency is missing" do
        allow(Wordbook::Utils).to receive(:log_error)
        expect(described_class.version_info("1.0.0")).to eq(
          [
            "Wordbook - 1.0.0",
            "Copyright 2016-2026 Mufeed Ali",
            "",
            "Dependency missing: espeak-ng is not installed or not in PATH.",
          ],
        )
      end
    end

    context "when espeak-ng exits non-zero" do
      before { stub_espeak("echo 'cannot read voice' >&2\nexit 1") }

      it "warns with the exit status and the stderr, and has no pronunciation" do
        expect(Wordbook::Utils).to receive(:log_warning)
          .with("espeak-ng failed for term 'cat'. RC: 1. Stderr: cannot read voice")
        expect(described_class.pronunciation("cat")).to be_nil
      end

      it "reports the version as unavailable rather than as missing" do
        expect(Wordbook::Utils).to receive(:log_error)
          .with("Failed to get espeak-ng version. RC: 1. Stderr: cannot read voice")
        expect(described_class.version_info("1.0.0").last)
          .to eq("Could not retrieve espeak-ng version information.")
      end
    end

    context "when espeak-ng exits zero but says nothing" do
      before { stub_espeak("exit 0") }

      # Upstream warns here too, with RC: 0 — its condition is
      # `if process.returncode == 0 and stdout` and the warning is the fall
      # through (`base.py:372-377`). An empty transcription is a failure to
      # pronounce, not a successful silence.
      it "warns with RC: 0 and has no pronunciation, as upstream does" do
        expect(Wordbook::Utils).to receive(:log_warning)
          .with("espeak-ng failed for term 'cat'. RC: 0. Stderr: ")
        expect(described_class.pronunciation("cat")).to be_nil
      end
    end

    context "when espeak-ng hangs" do
      before { stub_espeak("sleep 30") }

      it "kills it at the timeout, logs it and reports no status" do
        expect(Wordbook::Utils).to receive(:log_error)
          .with(/espeak-ng timed out: #{Wordbook::Espeak::BINARY} --version/)
        expect(described_class.run([Wordbook::Espeak::BINARY, "--version"], 0.5)).to eq([nil, "", ""])
      end

      it "leaves no child behind: the timeout path waits for the kill" do
        allow(Wordbook::Utils).to receive(:log_error)
        before_children = `ps -o pid= --ppid #{Process.pid}`.split.length
        described_class.run([Wordbook::Espeak::BINARY, "--version"], 0.5)
        expect(`ps -o pid= --ppid #{Process.pid}`.split.length).to be <= before_children
      end
    end

    context "when espeak-ng works" do
      before { stub_espeak(%(echo "/'kat/")) }

      it "strips the slashes, the newlines and the doubled spaces" do
        expect(described_class.pronunciation("cat")).to eq("'kat")
      end

      it "asks espeak-ng once per lemma and accent, as upstream's lru_cache does" do
        expect(described_class.pronunciation("cat")).to eq("'kat")
        stub_espeak("exit 1")
        expect(described_class.pronunciation("cat")).to eq("'kat")
      end

      it "caches a miss too, so a lemma espeak-ng cannot read is asked for once" do
        stub_espeak("exit 0")
        expect(described_class.pronunciation("zzz")).to be_nil
        expect(described_class.instance_variable_get(:@cache)).to have_key(["zzz", "us"])
      end

      # The eviction at :118. Without it the cache grows without bound for the
      # life of the process, which upstream's maxsize=128 does not.
      it "evicts the oldest entry once the cache is full" do
        (Wordbook::Espeak::CACHE_LIMIT + 10).times { |index| described_class.cache(["term#{index}", "us"], index) }
        expect(described_class.instance_variable_get(:@cache).size).to eq(Wordbook::Espeak::CACHE_LIMIT)
        expect(described_class.instance_variable_get(:@cache)).not_to have_key(["term0", "us"])
        expect(described_class.instance_variable_get(:@cache)).to have_key(["term137", "us"])
      end
    end
  end
end
