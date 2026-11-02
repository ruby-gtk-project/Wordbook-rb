# frozen_string_literal: true

require "fileutils"
require "sqlite3"

module Wordbook
  # WnFixture writes a tiny WordNet database in the schema the `wn` library
  # builds and `Wordbook::Base::Wordnet` queries — lexicons, entries, forms,
  # synsets, senses, definitions, examples, pronunciations and the two relation
  # tables.
  #
  # Why it exists: the real database is a 100MB zstd archive shipped by
  # upstream's meson build, and without one the window stops on its "Database
  # not found" page. Everything behind that page — the definition view, the
  # pronunciation rows, the relation chips, the completion popover, the history
  # — is then code no run has ever entered. This is the smallest lexicon that
  # exercises all of it:
  #
  #   * "word" is a noun, a verb and a phrase, so the content page gets three
  #     part-of-speech sections;
  #   * its noun synset carries two examples, two synonyms, an antonym (a
  #     sense relation, not a synset one), a "similar to" and an "also see",
  #     so every RelationBox kind is built;
  #   * "word" has an American and a British IPA, so switching the accent in
  #     the preferences changes what the page shows;
  #   * "dictionary" has no recorded pronunciation, so the espeak-ng fallback
  #     pass runs;
  #   * "words" is a rank-1 form of the "word" entry, so a search for it has
  #     to resolve back to the rank-0 lemma.
  module WnFixture
    LEXICON_ROWID = 1

    # The specifier Constants::WN_DB_VERSION names; a database without this
    # exact row makes Wordnet.open return nil.
    SPECIFIER = "oewn:2025+"

    SCHEMA = <<~SQL
      CREATE TABLE lexicons (
        rowid INTEGER PRIMARY KEY, id TEXT, label TEXT, version TEXT, specifier TEXT
      );
      CREATE TABLE entries (rowid INTEGER PRIMARY KEY, lexicon_rowid INTEGER, id TEXT);
      CREATE TABLE forms (
        rowid INTEGER PRIMARY KEY, entry_rowid INTEGER, form TEXT,
        normalized_form TEXT, rank INTEGER
      );
      CREATE TABLE synsets (
        rowid INTEGER PRIMARY KEY, lexicon_rowid INTEGER, id TEXT, pos TEXT
      );
      CREATE TABLE senses (
        rowid INTEGER PRIMARY KEY, entry_rowid INTEGER, synset_rowid INTEGER,
        entry_rank INTEGER
      );
      CREATE TABLE definitions (
        rowid INTEGER PRIMARY KEY, synset_rowid INTEGER, definition TEXT
      );
      CREATE TABLE synset_examples (
        rowid INTEGER PRIMARY KEY, synset_rowid INTEGER, example TEXT
      );
      CREATE TABLE pronunciations (
        rowid INTEGER PRIMARY KEY, form_rowid INTEGER, value TEXT, variety TEXT
      );
      CREATE TABLE relation_types (rowid INTEGER PRIMARY KEY, type TEXT);
      CREATE TABLE sense_relations (
        rowid INTEGER PRIMARY KEY, source_rowid INTEGER, target_rowid INTEGER,
        type_rowid INTEGER
      );
      CREATE TABLE synset_relations (
        rowid INTEGER PRIMARY KEY, source_rowid INTEGER, target_rowid INTEGER,
        type_rowid INTEGER
      );
    SQL

    # entry rowid => its forms, rank 0 first.
    ENTRIES = {
      1 => ["word", "words"],
      2 => ["term"],
      3 => ["vocable"],
      4 => ["silence"],
      5 => ["speak"],
      6 => ["dictionary"],
      7 => ["wordbook"],
      8 => ["lexicon"],
    }.freeze

    # synset rowid => [part-of-speech tag, definition, [entry rowids]]
    SYNSETS = {
      1 => ["n", "a unit of language that native speakers can identify", [1, 2, 3]],
      2 => ["v", "to express in words", [1, 5]],
      3 => ["n", "a reference book containing an alphabetical list of words", [6]],
      4 => ["n", "the absence of sound", [4]],
      5 => ["n", "a book of words", [7]],
      6 => ["n", "the vocabulary of a language", [8]],
      7 => ["t", "a promise given on one's honour", [1]],
    }.freeze

    EXAMPLES = {
      1 => ["he said a word in my ear", "mark my words"],
      2 => ["the letter was worded carefully"],
    }.freeze

    # form rowid => [[IPA, variety], …]. Keyed by form rather than by entry
    # because that is how the `wn` schema records them.
    PRONUNCIATIONS = {
      1 => [["/wɜːd/", "us"], ["/wəːd/", "gb"]],
    }.freeze

    RELATION_TYPES = { 1 => "antonym", 2 => "similar", 3 => "also" }.freeze

    def self.write(path)
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.rm_f(path)
      SQLite3::Database.new(path).tap do |database|
        database.execute_batch(SCHEMA)
        fill(database)
        database.close
      end
      path
    end

    def self.fill(database)
      database.execute(
        "INSERT INTO lexicons (rowid, id, label, version, specifier) VALUES (?, ?, ?, ?, ?)",
        [LEXICON_ROWID, "oewn", "Open English WordNet", "2025", SPECIFIER],
      )
      insert_entries(database)
      insert_synsets(database)
      insert_relations(database)
    end


    def self.insert_entries(database)
      form_rowid = 0
      ENTRIES.each do |entry_rowid, forms|
        database.execute(
          "INSERT INTO entries (rowid, lexicon_rowid, id) VALUES (?, ?, ?)",
          [entry_rowid, LEXICON_ROWID, "oewn-#{forms.first}"],
        )
        forms.each_with_index do |form, rank|
          form_rowid += 1
          database.execute(
            "INSERT INTO forms (rowid, entry_rowid, form, normalized_form, rank) VALUES (?, ?, ?, ?, ?)",
            [form_rowid, entry_rowid, form, form.downcase, rank],
          )
          Array(PRONUNCIATIONS[form_rowid]).each do |value, variety|
            database.execute(
              "INSERT INTO pronunciations (form_rowid, value, variety) VALUES (?, ?, ?)",
              [form_rowid, value, variety],
            )
          end
        end
      end
    end

    def self.insert_synsets(database)
      sense_rowid = 0
      SYNSETS.each do |synset_rowid, (pos, definition, entry_rowids)|
        database.execute(
          "INSERT INTO synsets (rowid, lexicon_rowid, id, pos) VALUES (?, ?, ?, ?)",
          [synset_rowid, LEXICON_ROWID, "oewn-#{synset_rowid}-#{pos}", pos],
        )
        database.execute(
          "INSERT INTO definitions (synset_rowid, definition) VALUES (?, ?)",
          [synset_rowid, definition],
        )
        Array(EXAMPLES[synset_rowid]).each do |example|
          database.execute(
            "INSERT INTO synset_examples (synset_rowid, example) VALUES (?, ?)",
            [synset_rowid, example],
          )
        end
        entry_rowids.each_with_index do |entry_rowid, entry_rank|
          sense_rowid += 1
          database.execute(
            "INSERT INTO senses (rowid, entry_rowid, synset_rowid, entry_rank) VALUES (?, ?, ?, ?)",
            [sense_rowid, entry_rowid, synset_rowid, entry_rank],
          )
        end
      end
    end

    # The antonym is between the "word" sense of synset 1 and the "silence"
    # sense of synset 4, which is where WordNet keeps antonymy; "similar" and
    # "also see" are between synsets.
    def self.insert_relations(database)
      RELATION_TYPES.each do |rowid, type|
        database.execute("INSERT INTO relation_types (rowid, type) VALUES (?, ?)", [rowid, type])
      end
      database.execute(
        "INSERT INTO sense_relations (source_rowid, target_rowid, type_rowid) VALUES (?, ?, ?)",
        [sense_rowid_for(1, 1), sense_rowid_for(4, 4), 1],
      )
      database.execute(
        "INSERT INTO synset_relations (source_rowid, target_rowid, type_rowid) VALUES (?, ?, ?)",
        [1, 5, 2],
      )
      database.execute(
        "INSERT INTO synset_relations (source_rowid, target_rowid, type_rowid) VALUES (?, ?, ?)",
        [1, 6, 3],
      )
    end

    # Senses are numbered in the order insert_synsets writes them, so the
    # rowid of one is derivable rather than looked up.
    def self.sense_rowid_for(synset_rowid, entry_rowid)
      SYNSETS.sum do |rowid, (_pos, _definition, entry_rowids)|
        if rowid < synset_rowid
          entry_rowids.length
        else
          0
        end
      end + SYNSETS.fetch(synset_rowid).last.index(entry_rowid) + 1
    end
  end
end
