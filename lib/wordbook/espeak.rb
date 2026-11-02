# frozen_string_literal: true

require "open3"

require_relative "utils"

module Wordbook
  # Espeak wraps the espeak-ng command line tool, ported from the espeak half
  # of upstream's wordbook/base.py: get_pronunciation, ipa_to_espeak, read_term
  # and the version banner get_version_info prints.
  #
  # Every call shells out with a timeout and treats a missing binary as "no
  # pronunciation available" rather than an error, which is what keeps the app
  # usable on a system without espeak-ng installed.
  #
  module Espeak
    BINARY = "espeak-ng"
    PRONUNCIATION_TIMEOUT = 5
    READ_TIMEOUT = 10
    DEFAULT_SPEED = 120
    DEFAULT_ACCENT = "us"
    CACHE_LIMIT = 128

    # A cached nil (espeak-ng had nothing to say) has to be distinguishable
    # from an absent entry, so the cache lookup needs a sentinel.
    MISS = Object.new

    # IPA to espeak-ng's own phoneme notation. Applied longest key first, so
    # the digraphs win over the single symbols they contain.
    IPA_TO_ESPEAK = {
      "ˈ"  => "'",
      "ˌ"  => ",",
      "ː"  => ":",
      "."  => "",
      "‿"  => "",
      "|"  => "",
      "‖"  => "",
      "tʃ" => "tS",
      "dʒ" => "dZ",
      "eɪ" => "eI",
      "aɪ" => "aI",
      "ɔɪ" => "OI",
      "aʊ" => "aU",
      "oʊ" => "oU",
      "əʊ" => "@U",
      "ɪə" => "I@",
      "eə" => "e@",
      "ɛə" => "e@",
      "ʊə" => "U@",
      "iː" => "i:",
      "ɑː" => "A:",
      "ɔː" => "O:",
      "uː" => "u:",
      "ɜː" => "3:",
      "ɚ"  => "@r",
      "ɝ"  => "3r",
      "ɪ"  => "I",
      "ɛ"  => "E",
      "e"  => "e",
      "æ"  => "a",
      "ɑ"  => "A",
      "ɒ"  => "0",
      "ɔ"  => "O",
      "ʊ"  => "U",
      "ʌ"  => "V",
      "ɜ"  => "3",
      "ə"  => "@",
      "ɐ"  => "@",
      "a"  => "a",
      "θ"  => "T",
      "ð"  => "D",
      "ʃ"  => "S",
      "ʒ"  => "Z",
      "ŋ"  => "N",
      "ɹ"  => "r",
      "ɾ"  => "4",
      "ɫ"  => "l",
      "ʔ"  => "?",
      "ʍ"  => "W",
      "x"  => "x",
      "ç"  => "C",
    }.freeze

    SORTED_IPA_KEYS = IPA_TO_ESPEAK.keys.sort_by { |symbol| -symbol.length }.freeze

    @cache = {}
    @cache_lock = Mutex.new

    # Wraps the converted phonemes in [[...]], which is how espeak-ng is told
    # to read phonemes rather than letters. Anything left outside ASCII after
    # the substitutions is dropped, as upstream does.
    def self.ipa_to_espeak(ipa_string)
      SORTED_IPA_KEYS.reduce(ipa_string.strip.gsub(/\A[\/\[\]]+|[\/\[\]]+\z/, "")) do |text, symbol|
        text.gsub(symbol, IPA_TO_ESPEAK.fetch(symbol))
      end.then { |text| "[[#{text.each_char.select { |char| char.ord < 128 }.join}]]" }
    end

    # The IPA espeak-ng derives for a term, used as the fallback when WordNet
    # itself has no pronunciation recorded for a lemma. Memoized the way
    # upstream's @lru_cache(maxsize=128) is, since the same lemma is asked for
    # once per synset on a page.
    def self.pronunciation(term, accent = DEFAULT_ACCENT)
      [term, accent].then do |key|
        @cache_lock.synchronize { @cache.fetch(key, MISS) }.then do |cached|
          if cached.equal?(MISS)
            cache(key, read_pronunciation(term, accent))
          else
            cached
          end
        end
      end
    end

    def self.cache(key, value)
      @cache_lock.synchronize do
        @cache[key] = value
        while @cache.size > CACHE_LIMIT
          @cache.delete(@cache.each_key.first)
        end
        value
      end
    end

    def self.read_pronunciation(term, accent)
      run([BINARY, "-v", "en-#{accent}", "--ipa=3", "-q", term], PRONUNCIATION_TIMEOUT).then do |status, stdout, stderr|
        if status&.zero? && !stdout.strip.empty?
          stdout.strip.tr("\n", " ").gsub("  ", " ").gsub(/\A\/+|\/+\z/, "")
        else
          if status
            Utils.log_warning("espeak-ng failed for term '#{term}'. RC: #{status}. Stderr: #{stderr.strip}")
          end
          nil
        end
      end
    end

    # Speaks the term. With an IPA string the phonemes are handed over
    # directly, so the accent the user picked is what is heard; without one
    # espeak-ng reads the letters.
    def self.read_term(text, speed: DEFAULT_SPEED, accent: DEFAULT_ACCENT, ipa: nil)
      phoneme_input(text, ipa).then do |input|
        run([BINARY, "-s", speed.to_s, "-v", "en-#{accent}", input], READ_TIMEOUT)
      end
    end

    def self.phoneme_input(text, ipa)
      if ipa.to_s.empty?
        text
      else
        ipa_to_espeak(ipa)
      end
    end

    # Upstream's get_version_info: the app banner plus espeak-ng's own version.
    def self.version_info(app_version)
      ["Wordbook - #{app_version}", "Copyright 2016-2026 Mufeed Ali", ""].then do |lines|
        run([BINARY, "--version"], PRONUNCIATION_TIMEOUT).then do |status, stdout, stderr|
          if status&.zero? && !stdout.strip.empty?
            lines + [stdout.strip]
          else
            if status
              Utils.log_error("Failed to get espeak-ng version. RC: #{status}. Stderr: #{stderr.strip}")
            end
            lines + [version_failure_message(status)]
          end
        end
      end
    end

    def self.version_failure_message(status)
      if status
        "Could not retrieve espeak-ng version information."
      else
        "Dependency missing: espeak-ng is not installed or not in PATH."
      end
    end

    # Runs the command and returns [exit status, stdout, stderr]. A nil status
    # means the process never ran or never finished: a missing binary, a
    # timeout, or an OS-level failure, each of which upstream logs and treats
    # as no result.
    def self.run(command, timeout)
      Open3.popen3(*command) do |stdin, stdout, stderr, wait_thread|
        stdin.close
        if wait_thread.join(timeout)
          [wait_thread.value.exitstatus, stdout.read, stderr.read]
        else
          Process.kill("TERM", wait_thread.pid)
          wait_thread.join
          Utils.log_error("espeak-ng timed out: #{command.join(" ")}")
          [nil, "", ""]
        end
      end
    rescue Errno::ENOENT
      Utils.log_error("'espeak-ng' command not found. Please install espeak-ng.")
      [nil, "", ""]
    rescue SystemCallError => e
      Utils.log_error("OS error executing espeak-ng: #{e.message}")
      [nil, "", ""]
    end
  end
end
