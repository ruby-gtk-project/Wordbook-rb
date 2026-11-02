# frozen_string_literal: true

require_relative "constants"
require_relative "database_manager"
require_relative "espeak"
require_relative "utils"

module Wordbook
  # Base is the UI-independent half of the app: cleaning search terms, reading
  # WordNet and shaping what it returns into the structure the definition view
  # renders. Ported from upstream's wordbook/base.py, minus the espeak-ng calls,
  # which live in espeak.rb.
  #
  # Upstream leans on the `wn` Python library for the lookups. `wn` is a reader
  # for a SQLite database built from the WNDB XML, and the bundled
  # wn-<version>.db this app ships *is* that database, so this port queries it
  # directly: the Wordnet class below holds the handful of statements the app
  # needs against wn's schema (entries/forms/senses/synsets and their relation
  # tables) instead of reimplementing the library's object model.
  #
  # Two scorers upstream gets from dependencies are written out here rather
  # than pulled in, and they are not the same scorer:
  #
  #   * the "Did you mean" suggestions use rapidfuzz's `fuzz.QRatio`
  #     (`wordbook/window.py:340`), which is the indel ratio applied to
  #     rapidfuzz's `default_process` of both strings — lowercased, with every
  #     non-alphanumeric character turned into a space, then trimmed. That is
  #     `qratio` below. The first version of this file omitted the processing
  #     and scored the raw strings downcased, which gave a different five
  #     suggestions for every hyphenated or multi-word lemma;
  #   * the close-lemma match uses `difflib.get_close_matches(..., cutoff=0.8)`
  #     (`wordbook/base.py:244`), which is case-sensitive and scores with
  #     Ratcliff/Obershelp rather than with an indel ratio. `ratio` below is
  #     the indel ratio on the raw strings: the case sensitivity matches, the
  #     algorithm does not, so the lemma this port picks for a near-miss search
  #     can still differ from upstream's. Recorded in COMPONENT_PARITY.md.
  #
  module Base
    DEFAULT_ACCENT = "us"
    SUGGESTION_LIMIT = 5
    SUGGESTION_CUTOFF = 70
    CLOSE_MATCH_CUTOFF = 80

    WN_DIR = File.join(Utils::DATA_DIR, "wn-#{Constants::WN_FILE_VERSION}")

    # One IPA string for a lemma. `fallback` marks the ones espeak-ng derived
    # because WordNet had none: those are read aloud as letters rather than as
    # phonemes, since they are a guess at the spelling's pronunciation already.
    PronunciationInfo = Data.define(:ipa, :fallback) do
      def self.of(ipa, fallback: false) = new(ipa: ipa, fallback: fallback)
      def fallback? = fallback == true
      def key = [ipa, fallback?]
    end

    # The definition page's grouping: a lemma, and under it one block per
    # distinct pronunciation, each holding the synsets that share it.
    PronunciationGroup = Data.define(:pronunciation, :synsets)
    LemmaGroup = Data.define(:lemma, :pronunciation_groups)

    # One synset as the database has it, before a search term is matched
    # against it.
    Synset = Data.define(
      :pos,
      :lemmas,
      :definition,
      :examples,
      :pronunciations,
      :antonyms,
      :similar,
      :also,
    )

    NO_DEFINITION = "No definition available."

    # Upstream's WN_DATABASE_LOCK: the searches run on background threads and
    # share one connection.
    DATABASE_LOCK = Mutex.new

    def self.create_required_dirs = Utils.create_required_dirs(WN_DIR)

    # Strips the punctuation a search term is never meant to carry, both from
    # its ends and from inside it.
    def self.clean_search_terms(search_term)
      search_term.to_s.strip
                 .gsub(/\A[#{Regexp.escape(Constants::SEARCH_TERM_CLEANUP_CHARS)}]+/, "")
                 .gsub(/[#{Regexp.escape(Constants::SEARCH_TERM_CLEANUP_CHARS)}]+\z/, "")
                 .then do |text|
        Constants::SEARCH_TERM_REPLACE_CHARS.reduce(text) { |cleaned, char| cleaned.gsub(char, "") }
      end
    end

    # --- WordNet -------------------------------------------------------------

    # Wordnet reads the bundled database. One instance per run, created by
    # `Base.wordnet` once DatabaseManager has put the file in place.
    class Wordnet
      SYNSETS_SQL = <<~SQL
        SELECT DISTINCT ss.rowid AS rowid, ss.pos AS pos, MIN(s.entry_rank) AS entry_rank
        FROM synsets ss
        JOIN senses s ON s.synset_rowid = ss.rowid
        JOIN forms f ON f.entry_rowid = s.entry_rowid
        WHERE ss.lexicon_rowid = :lexicon
          AND (f.form = :form OR f.normalized_form = :form)
        GROUP BY ss.rowid
        ORDER BY entry_rank, ss.rowid
      SQL

      # The lemma of an entry is its rank-0 form; the subselect picks it
      # without assuming the rank was recorded.
      LEMMA_FORM = <<~SQL
        (SELECT rowid FROM forms WHERE entry_rowid = %<entry>s ORDER BY rank, rowid LIMIT 1)
      SQL

      LEMMAS_SQL = <<~SQL
        SELECT lf.form AS form
        FROM senses s
        JOIN forms lf ON lf.rowid = #{format(LEMMA_FORM, entry: "s.entry_rowid")}
        WHERE s.synset_rowid = :synset
        ORDER BY s.entry_rank, s.rowid
      SQL

      DEFINITION_SQL = <<~SQL
        SELECT definition FROM definitions WHERE synset_rowid = :synset ORDER BY rowid LIMIT 1
      SQL

      EXAMPLES_SQL = <<~SQL
        SELECT example FROM synset_examples WHERE synset_rowid = :synset ORDER BY rowid
      SQL

      PRONUNCIATIONS_SQL = <<~SQL
        SELECT lf.form AS form, p.value AS value, p.variety AS variety
        FROM senses s
        JOIN forms lf ON lf.rowid = #{format(LEMMA_FORM, entry: "s.entry_rowid")}
        JOIN pronunciations p ON p.form_rowid = lf.rowid
        WHERE s.synset_rowid = :synset
        ORDER BY s.rowid, p.rowid
      SQL

      # Antonymy is recorded between senses, not synsets, which is why
      # upstream walks the synset's senses to collect it.
      ANTONYMS_SQL = <<~SQL
        SELECT lf.form AS form
        FROM senses s
        JOIN sense_relations r ON r.source_rowid = s.rowid
        JOIN relation_types rt ON rt.rowid = r.type_rowid
        JOIN senses ts ON ts.rowid = r.target_rowid
        JOIN forms lf ON lf.rowid = #{format(LEMMA_FORM, entry: "ts.entry_rowid")}
        WHERE s.synset_rowid = :synset AND rt.type = 'antonym'
        ORDER BY s.rowid, r.rowid
      SQL

      RELATED_SQL = <<~SQL
        SELECT lf.form AS form
        FROM synset_relations r
        JOIN relation_types rt ON rt.rowid = r.type_rowid
        JOIN senses ts ON ts.synset_rowid = r.target_rowid
        JOIN forms lf ON lf.rowid = #{format(LEMMA_FORM, entry: "ts.entry_rowid")}
        WHERE r.source_rowid = :synset AND rt.type = :type
        ORDER BY r.rowid, ts.entry_rank, ts.rowid
      SQL

      WORDLIST_SQL = <<~SQL
        SELECT DISTINCT lf.form AS form
        FROM entries e
        JOIN forms lf ON lf.rowid = #{format(LEMMA_FORM, entry: "e.rowid")}
        WHERE e.lexicon_rowid = :lexicon
      SQL

      LEXICON_SQL = "SELECT rowid FROM lexicons WHERE specifier = :specifier LIMIT 1"

      # Returns nil rather than raising when the database is missing or does
      # not hold the expected lexicon, which is what upstream's
      # get_wn_instance does with wn.Error.
      def self.open(path: DatabaseManager.extracted_db_path, specifier: Constants::WN_DB_VERSION)
        # Required here rather than at the top of the file so that the rest of
        # Base — the term cleaning, the scorers, the grouping, all of which are
        # plain string work — can be loaded and tested without the database
        # driver present.
        require "sqlite3"
        Utils.log_info("Initializing WordNet...")
        SQLite3::Database.new(path, readonly: true).then do |database|
          database.results_as_hash = true
          new(database, specifier).tap { Utils.log_info("WordNet instance (#{specifier}) created and ready.") }
        end
      rescue SQLite3::Exception, SystemCallError, ArgumentError => e
        Utils.log_error("WordNet initialization failed: #{e.message}")
        nil
      end

      attr_reader :specifier

      def initialize(database, specifier)
        @database = database
        @specifier = specifier
        @lexicon = lexicon_rowid
      end

      def close = @database.close

      # Every synset the form appears in, each one carrying its lemmas,
      # definition, examples, pronunciations and relations.
      def synsets(form)
        rows(SYNSETS_SQL, form: form.to_s, lexicon: @lexicon).map { |row| synset(row) }
      end

      # The whole lexicon's lemmas, which is what the completion popover and
      # the random-word action pick from.
      def lemmas = rows(WORDLIST_SQL, lexicon: @lexicon).map { |row| row["form"] }

      private

        def lexicon_rowid
          rows(LEXICON_SQL, specifier: @specifier).first.then do |row|
            unless row
              raise ArgumentError, "No lexicon #{@specifier} in this database"
            end
            row["rowid"]
          end
        end

        def synset(row)
          row["rowid"].then do |rowid|
            Synset.new(
              pos:            row["pos"],
              lemmas:         forms(LEMMAS_SQL, synset: rowid),
              definition:     definition(rowid),
              examples:       rows(EXAMPLES_SQL, synset: rowid).map { |example| example["example"] }.compact,
              pronunciations: pronunciations(rowid),
              antonyms:       forms(ANTONYMS_SQL, synset: rowid),
              similar:        forms(RELATED_SQL, synset: rowid, type: "similar"),
              also:           forms(RELATED_SQL, synset: rowid, type: "also"),
            )
          end
        end

        def definition(rowid)
          rows(DEFINITION_SQL, synset: rowid).first.then do |row|
            row && row["definition"]
          end
        end

        # Keyed by the lemma, downcased, because that is how the matched search
        # term is looked up against it.
        def pronunciations(rowid)
          rows(PRONUNCIATIONS_SQL, synset: rowid).each_with_object({}) do |row, by_lemma|
            Base.normalize_lemma(row["form"]).downcase.then do |lemma|
              (by_lemma[lemma] ||= []) << { value: row["value"].to_s, variety: row["variety"] }
            end
          end
        end

        def forms(sql, **binds) = rows(sql, **binds).map { |row| row["form"] }.compact

        def rows(sql, **binds)
          @database.execute(sql, binds.transform_keys { |key| ":#{key}" })
        end
    end

    # The instance the window hands to every search. nil means the database is
    # not usable, which lands the window on its "Database not found" page.
    def self.wordnet = Wordnet.open

    # Upstream loads the wordlist on a thread because it is a six-figure row
    # count; the callback is invoked with the lemmas, or with an empty list if
    # the read failed.
    def self.wordlist(wordnet, &on_complete)
      Utils.log_info("Fetching WordNet wordlist...")
      Thread.new do
        Thread.current.name = "wordlist"
        begin
          DATABASE_LOCK.synchronize { wordnet.lemmas }.then do |lemmas|
            Utils.log_info("WordNet wordlist fetched (#{lemmas.length} lemmas).")
            on_complete.call(lemmas)
          end
        rescue StandardError => e
          Utils.log_error("Error fetching WordNet wordlist: #{e.message}")
          on_complete.call([])
        end
      end
    end

    # --- Definitions ---------------------------------------------------------

    # Upstream's format_output: the entry point a search goes through. Returns
    # nil for input that cleans away to nothing.
    def self.format_output(text, wordnet, accent: DEFAULT_ACCENT)
      clean_search_terms(text).then do |cleaned|
        if cleaned.strip.empty?
          Utils.log_info("Input '#{text}' became empty after cleaning.")
          nil
        else
          fetch_definition(cleaned, wordnet, accent: accent)
        end
      end
    end

    # The definition data plus the espeak-ng fallback pass: any synset of the
    # resolved term that WordNet has no pronunciation for borrows one derived
    # from the spelling, so a page never shows some lemmas with an IPA and
    # others without.
    def self.fetch_definition(term, wordnet, accent: DEFAULT_ACCENT)
      DATABASE_LOCK.synchronize { get_definition(term, wordnet, accent: accent) }.then do |data|
        if data[:result]
          apply_fallback_pronunciation(data, accent)
        else
          data
        end
      end
    end

    def self.apply_fallback_pronunciation(data, accent)
      data[:term].to_s.downcase.then do |resolved|
        missing = synsets_missing_pronunciation(data, resolved)
        if missing.empty?
          data
        else
          fill_fallback(data, missing, accent)
        end
      end
    end

    def self.synsets_missing_pronunciation(data, resolved)
      data[:result].values.flatten.select do |synset|
        synset[:pronunciation].nil? && synset[:name].to_s.downcase == resolved
      end
    end

    def self.fill_fallback(data, missing, accent)
      Espeak.pronunciation(data[:term], accent).then do |ipa|
        if ipa.to_s.empty?
          data
        else
          PronunciationInfo.of(ipa, fallback: true).then do |fallback|
            missing.each { |synset| synset[:pronunciation] = fallback }
            data
          end
        end
      end
    end

    # Upstream's get_definition: the synsets for a term, grouped by part of
    # speech, each one carrying the lemma the term matched, the definition, the
    # examples, a pronunciation and the related lemmas.
    def self.get_definition(term, wordnet, accent: DEFAULT_ACCENT)
      wordnet.synsets(term.downcase).then do |synsets|
        if synsets.empty?
          { term: term, result: nil }
        else
          build_definition(term, synsets, accent)
        end
      end
    end

    def self.build_definition(term, synsets, accent)
      first_match = nil
      result = Constants::POS_NAMES.to_h { |pos| [pos, []] }

      synsets.each do |synset|
        unless synset.lemmas.empty?
          matched = find_best_lemma_match(term, synset.lemmas)
          first_match ||= matched
          result[pos_name(synset.pos, term)] << synset_data(synset, matched, accent)
        end
      end

      { term: first_match || term, result: result }
    end

    def self.pos_name(pos_tag, term)
      Constants::POS_MAP.fetch(pos_tag.to_s) do
        Utils.log_warning("Unknown POS tag encountered: #{pos_tag} for term '#{term}'")
        Constants::POS_MAP.fetch("u")
      end
    end

    def self.synset_data(synset, matched_lemma, accent)
      {
        name:          matched_lemma,
        definition:    blank_to_default(synset.definition),
        examples:      synset.examples,
        pronunciation: pick_pronunciation(synset.pronunciations[matched_lemma.downcase], accent),
      }.merge(related_lemmas(synset, matched_lemma))
    end

    def self.blank_to_default(definition)
      if definition.to_s.strip.empty?
        NO_DEFINITION
      else
        definition
      end
    end

    # Upstream's _pick_pronunciation: the variety the user asked for, else
    # whichever one WordNet lists first.
    def self.pick_pronunciation(pronunciations, accent)
      Array(pronunciations).reject { |pron| pron[:value].to_s.empty? }.then do |available|
        requested = accent.to_s.strip.downcase
        available.find { |pron| matching_variety?(pron, requested) }.then do |chosen|
          (chosen || available.first).then do |pron|
            if pron
              PronunciationInfo.of(pron[:value])
            end
          end
        end
      end
    end

    def self.matching_variety?(pronunciation, requested)
      pronunciation[:variety].to_s.strip.downcase.then do |variety|
        !variety.empty? && variety == requested
      end
    end

    # Synonyms, antonyms, similar terms and "also see", each with the matched
    # lemma itself filtered out and duplicates dropped.
    def self.related_lemmas(synset, matched_lemma)
      {
        syn:       without_matched(synset.lemmas, matched_lemma),
        ant:       unique_lemmas(synset.antonyms),
        sim:       without_matched(synset.similar, matched_lemma),
        also_sees: without_matched(synset.also, matched_lemma),
      }
    end

    def self.without_matched(lemmas, matched_lemma)
      matched_lemma.downcase.then do |matched|
        unique_lemmas(lemmas).reject { |lemma| lemma.downcase == matched }
      end
    end

    def self.unique_lemmas(lemmas) = lemmas.map { |lemma| normalize_lemma(lemma) }.uniq

    def self.normalize_lemma(lemma) = lemma.to_s.tr("_", " ").strip

    # Upstream's _find_best_lemma_match: an exact match on the search term
    # first, then the closest lemma above the cutoff, then whatever came first.
    def self.find_best_lemma_match(term, lemmas)
      term.downcase.strip.then do |normalized_term|
        lemmas.find { |lemma| normalize_lemma(lemma).downcase == normalized_term }
              .then { |exact| exact || close_match(term, lemmas) }
              .then { |lemma| normalize_lemma(lemma || lemmas.first) }
      end
    end

    def self.close_match(term, lemmas)
      lemmas.map { |lemma| [ratio(term, lemma), lemma] }
            .select { |score, _lemma| score >= CLOSE_MATCH_CUTOFF }
            .max_by { |score, _lemma| score }
            .then { |best| best && best.last }
    end

    # --- Grouping ------------------------------------------------------------

    # Upstream's group_synsets_by_lemma: the page shows one header per lemma,
    # and a separate header for each pronunciation that lemma has, with the
    # synsets numbered under it.
    def self.group_synsets_by_lemma(synsets)
      synsets.each_with_object({}) do |synset, lemma_groups|
        ((lemma_groups[synset[:name]] ||= {})[pronunciation_key(synset[:pronunciation])] ||= []) << synset
      end.map do |lemma, pronunciation_groups|
        LemmaGroup.new(
          lemma:                lemma,
          pronunciation_groups: pronunciation_groups.values.map do |group|
            PronunciationGroup.new(pronunciation: group.first[:pronunciation], synsets: group)
          end,
        )
      end
    end

    def self.pronunciation_key(pronunciation)
      if pronunciation
        pronunciation.key
      else
        ["", false]
      end
    end

    # --- Suggestions ---------------------------------------------------------

    # Upstream asks rapidfuzz for the five closest words when a search finds
    # nothing, then keeps the ones scoring strictly above 70
    # (`window.py:340,373` — `score_cutoff=70` admits 70 and the list
    # comprehension then drops it). The length filter below only skips words
    # that cannot clear the cutoff: with matches capped at the shorter length,
    # 200 * min / (len1 + len2) is an upper bound on the score.
    def self.suggestions(term, wordlist, limit: SUGGESTION_LIMIT, cutoff: SUGGESTION_CUTOFF)
      if term.length > 2
        scored_suggestions(term, wordlist, cutoff).sort_by { |word, score| [-score, word] }.first(limit)
      else
        []
      end
    end

    def self.scored_suggestions(term, wordlist, cutoff)
      Array(wordlist).filter_map do |word|
        if feasible?(term, word, cutoff)
          scored(term, word, cutoff)
        end
      end
    end

    def self.scored(term, word, cutoff)
      qratio(term, word).then do |score|
        if score > cutoff
          [word, score]
        end
      end
    end

    def self.feasible?(term, word, cutoff)
      (200.0 * [term.length, word.length].min / (term.length + word.length)) > cutoff
    end

    # rapidfuzz's fuzz.QRatio: default_process both sides, then the indel
    # ratio.
    def self.qratio(first, second) = ratio(default_process(first), default_process(second))

    # rapidfuzz.utils.default_process: every non-alphanumeric character becomes
    # a space — a space, not nothing, so "re-read" scores as "re read" and not
    # as "reread" — then the result is trimmed and lowercased.
    def self.default_process(text) = text.to_s.gsub(/[^[:alnum:]]/, " ").strip.downcase

    # The indel similarity on a 0-100 scale: twice the number of characters in
    # the longest common subsequence over the combined length. Case-sensitive,
    # as difflib is; `qratio` is what lowercases.
    def self.ratio(first, second)
      first.to_s.then do |left|
        second.to_s.then do |right|
          if left.empty? && right.empty?
            100.0
          else
            200.0 * common_length(left, right) / (left.length + right.length)
          end
        end
      end
    end

    # Longest common subsequence length, computed a row at a time so the table
    # stays O(min length) in memory.
    def self.common_length(left, right)
      left.chars.reduce(Array.new(right.length + 1, 0)) { |previous, char| next_row(previous, char, right) }.last
    end

    def self.next_row(previous, char, right)
      right.chars.each_with_index.each_with_object(Array.new(right.length + 1, 0)) do |(other, index), row|
        if char == other
          row[index + 1] = previous[index] + 1
        else
          row[index + 1] = [row[index], previous[index + 1]].max
        end
      end
    end
  end
end
