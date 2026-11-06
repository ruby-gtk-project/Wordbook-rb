# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "zstd-ruby"

require_relative "constants"
require_relative "lmf_reader"

module Wordbook
  # DatabaseBuilder turns a WN-LMF lexicon into the compressed SQLite database
  # the app ships and DatabaseManager unpacks. It is the port of upstream's
  # scripts/generate-wn-db.py, whose meson `custom_target` builds
  # `wn-<version>.db.zst` into pkgdatadir (data/meson.build:4-16).
  #
  # Upstream delegates the XML-to-SQLite half to the `wn` package it vendors as
  # a git submodule (`wn.add`, subprojects/wn); there is no Ruby `wn`, so the
  # loading is here. That makes this file the one place in the port that
  # *writes* the schema lib/wordbook/base.rb reads, and the two have to agree:
  # the tables and columns below are exactly the ones Base::Wordnet's queries
  # name, and test/wn_fixture.rb writes the same shape by hand for the drive.
  #
  # One column is here that the fixture does not have: `senses.id`. WN-LMF
  # records antonymy as a `SenseRelation` whose target is a sense *id*, and the
  # senses it points at usually appear later in the document than the relation
  # does, so the ids have to be resolvable after the whole file is read. The
  # real `wn` schema carries the column too. Nothing in the app selects it.
  #
  # References that cannot be resolved while streaming — a sense's synset, a
  # relation's target — are staged in `pending_*` tables and turned into rowids
  # by three statements once the document is in, which keeps the memory cost
  # flat: the 2025 lexicon is 160 MB of XML, 162k entries, 213k senses, 121k
  # synsets and 420k relations, and holding that in Ruby objects to resolve it
  # in memory costs more than the database itself.
  class DatabaseBuilder
    class Error < StandardError; end

    DEFAULT_COMPRESSION_LEVEL = 15
    COMPRESSION_LEVELS = (1..22)

    # The URLs upstream's generate-wn-db.py downloads from, in its order: the
    # GitHub release first, the project's own mirror second.
    SOURCE_URLS = [
      "https://github.com/globalwordnet/english-wordnet/releases/download/2025-edition/english-wordnet-2025-plus.xml.gz",
      "https://en-word.net/static/english-wordnet-2025-plus.xml.gz",
    ].freeze

    # `PRAGMA journal_mode = OFF` and `synchronous = OFF` are safe here and
    # nowhere else in the port: this database is written once, into a temporary
    # directory, and is thrown away rather than repaired if the build dies.
    PRAGMAS = <<~SQL
      PRAGMA journal_mode = OFF;
      PRAGMA synchronous = OFF;
      PRAGMA temp_store = MEMORY;
      PRAGMA cache_size = -64000;
    SQL

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
        rowid INTEGER PRIMARY KEY, id TEXT, entry_rowid INTEGER,
        synset_rowid INTEGER, entry_rank INTEGER
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
      CREATE TABLE pending_sense_synsets (sense_rowid INTEGER, synset_id TEXT);
      CREATE TABLE pending_sense_relations (source_rowid INTEGER, target_id TEXT, type TEXT);
      CREATE TABLE pending_synset_relations (source_rowid INTEGER, target_id TEXT, type TEXT);
    SQL

    # The indexes the resolution statements below join on. They are created
    # after the load rather than before it so the inserts do not maintain them.
    RESOLUTION_INDEXES = <<~SQL
      CREATE INDEX synsets_id ON synsets (id);
      CREATE INDEX senses_id ON senses (id);
      CREATE INDEX pending_sense_synsets_sense ON pending_sense_synsets (sense_rowid);
    SQL

    RESOLVE_SENSE_SYNSETS = <<~SQL
      UPDATE senses SET synset_rowid = (
        SELECT s.rowid
        FROM pending_sense_synsets p
        JOIN synsets s ON s.id = p.synset_id
        WHERE p.sense_rowid = senses.rowid
      )
    SQL

    COLLECT_RELATION_TYPES = <<~SQL
      INSERT INTO relation_types (type)
      SELECT type FROM pending_sense_relations
      UNION
      SELECT type FROM pending_synset_relations
    SQL

    # ORDER BY the staged rowid so the relations keep the order the document
    # listed them in: Base::Wordnet's ANTONYMS_SQL and RELATED_SQL order by
    # relation rowid, and that order is what the relation chips are drawn in.
    RESOLVE_SENSE_RELATIONS = <<~SQL
      INSERT INTO sense_relations (source_rowid, target_rowid, type_rowid)
      SELECT p.source_rowid, t.rowid, rt.rowid
      FROM pending_sense_relations p
      JOIN senses t ON t.id = p.target_id
      JOIN relation_types rt ON rt.type = p.type
      ORDER BY p.rowid
    SQL

    RESOLVE_SYNSET_RELATIONS = <<~SQL
      INSERT INTO synset_relations (source_rowid, target_rowid, type_rowid)
      SELECT p.source_rowid, t.rowid, rt.rowid
      FROM pending_synset_relations p
      JOIN synsets t ON t.id = p.target_id
      JOIN relation_types rt ON rt.type = p.type
      ORDER BY p.rowid
    SQL

    DROP_STAGING = <<~SQL
      DROP INDEX pending_sense_synsets_sense;
      DROP TABLE pending_sense_synsets;
      DROP TABLE pending_sense_relations;
      DROP TABLE pending_synset_relations;
    SQL

    # One index per lookup Base::Wordnet makes. Without them a search is a
    # sequence of full scans over 1.7 million rows and the window sits on its
    # spinner page for seconds.
    RUNTIME_INDEXES = <<~SQL
      CREATE INDEX lexicons_specifier ON lexicons (specifier);
      CREATE INDEX forms_form ON forms (form);
      CREATE INDEX forms_normalized_form ON forms (normalized_form);
      CREATE INDEX forms_entry ON forms (entry_rowid, rank);
      CREATE INDEX senses_synset ON senses (synset_rowid, entry_rank);
      CREATE INDEX senses_entry ON senses (entry_rowid);
      CREATE INDEX definitions_synset ON definitions (synset_rowid);
      CREATE INDEX synset_examples_synset ON synset_examples (synset_rowid);
      CREATE INDEX pronunciations_form ON pronunciations (form_rowid);
      CREATE INDEX sense_relations_source ON sense_relations (source_rowid);
      CREATE INDEX synset_relations_source ON synset_relations (source_rowid);
      CREATE INDEX relation_types_type ON relation_types (type);
      CREATE INDEX entries_lexicon ON entries (lexicon_rowid);
    SQL

    INSERT_LEXICON = "INSERT INTO lexicons (id, label, version, specifier) VALUES (?, ?, ?, ?)"
    INSERT_ENTRY = "INSERT INTO entries (lexicon_rowid, id) VALUES (?, ?)"
    INSERT_FORM = "INSERT INTO forms (entry_rowid, form, normalized_form, rank) VALUES (?, ?, ?, ?)"
    INSERT_PRONUNCIATION = "INSERT INTO pronunciations (form_rowid, value, variety) VALUES (?, ?, ?)"
    INSERT_SENSE = "INSERT INTO senses (id, entry_rowid, entry_rank) VALUES (?, ?, ?)"
    INSERT_SYNSET = "INSERT INTO synsets (lexicon_rowid, id, pos) VALUES (?, ?, ?)"
    INSERT_DEFINITION = "INSERT INTO definitions (synset_rowid, definition) VALUES (?, ?)"
    INSERT_EXAMPLE = "INSERT INTO synset_examples (synset_rowid, example) VALUES (?, ?)"
    STAGE_SENSE_SYNSET = "INSERT INTO pending_sense_synsets (sense_rowid, synset_id) VALUES (?, ?)"
    STAGE_SENSE_RELATION = "INSERT INTO pending_sense_relations (source_rowid, target_id, type) VALUES (?, ?, ?)"
    STAGE_SYNSET_RELATION = "INSERT INTO pending_synset_relations (source_rowid, target_id, type) VALUES (?, ?, ?)"

    # How often the entry and synset counters are reported, in rows.
    REPORT_EVERY = 20_000

    # The default name is the one DatabaseManager hunts for in
    # <datadir>/wordbook: a database built under a different WN_FILE_VERSION
    # than the app was built with is invisible to it, which is the whole point
    # of the version being in the name.
    def self.default_output = "data/wn-#{Constants::WN_FILE_VERSION}.db.zst"

    def initialize(source:, output: self.class.default_output, compression_level: DEFAULT_COMPRESSION_LEVEL, progress: nil)
      unless COMPRESSION_LEVELS.cover?(compression_level)
        raise ArgumentError, "compression level #{compression_level} is outside #{COMPRESSION_LEVELS}"
      end

      @source = source
      @output = output
      @compression_level = compression_level
      @progress = progress
      @statements = {}
      @specifiers = []
      @counts = { entries: 0, senses: 0, synsets: 0 }
    end

    attr_reader :counts, :output, :specifiers

    # Reads the lexicon, writes the database into a temporary directory and
    # leaves the compressed copy at `output`. Returns the output path.
    def build
      Dir.mktmpdir("wordbook-wn") do |workspace|
        File.join(workspace, "wn.db").then do |db_path|
          write_database(db_path)
          compress(db_path)
        end
      end
      @output
    end

    private

      def write_database(path)
        # Required here, not at the top of the file, so that a reader of the
        # lexicon can be loaded without the database driver: the same reason
        # Base::Wordnet.open requires it where it does.
        require "sqlite3"
        SQLite3::Database.new(path).tap do |database|
          @database = database
          database.execute_batch(PRAGMAS)
          database.execute_batch(SCHEMA)
          database.transaction { read_lexicon }
          database.transaction { resolve_references }
          finish(database)
        end
      end

      def finish(database)
        report("Indexing")
        database.execute_batch(RUNTIME_INDEXES)
        database.execute_batch(DROP_STAGING)
        close_statements
        # ANALYZE writes sqlite_stat1, which is what makes the planner pick
        # forms_form over a scan on a query whose WHERE clause is an OR across
        # two indexed columns — Base::Wordnet's SYNSETS_SQL is exactly that.
        report("Analysing")
        database.execute("ANALYZE")
        report("Vacuuming")
        database.execute("VACUUM")
        database.close
      end

      def read_lexicon
        report("Reading #{@source}")
        LmfReader.open(@source) do |reader|
          reader.each { |kind, name, payload| handle(kind, name, payload) }
        end
        report("Read #{@counts[:entries]} entries, #{@counts[:senses]} senses, #{@counts[:synsets]} synsets")
      end

      def resolve_references
        report("Resolving senses and relations")
        @database.execute_batch(RESOLUTION_INDEXES)
        @database.execute(RESOLVE_SENSE_SYNSETS)
        @database.execute(COLLECT_RELATION_TYPES)
        @database.execute(RESOLVE_SENSE_RELATIONS)
        @database.execute(RESOLVE_SYNSET_RELATIONS)
      end

      def handle(kind, name, payload)
        if kind == :start
          open_element(name, payload)
        else
          close_element(name, payload)
        end
      end

      # Elements WN-LMF allows that the app never reads — ILIDefinition,
      # SyntacticBehaviour, Requires, the dc: metadata — fall through both of
      # these, which is why neither has an else branch.
      def open_element(name, attributes)
        case name
        when "Lexicon" then start_lexicon(attributes)
        when "LexicalEntry" then start_entry(attributes)
        when "Lemma" then start_lemma(attributes)
        when "Form" then start_form(attributes)
        when "Pronunciation" then @variety = attributes["variety"]
        when "Sense" then start_sense(attributes)
        when "SenseRelation" then stage_sense_relation(attributes)
        when "Synset" then start_synset(attributes)
        when "SynsetRelation" then stage_synset_relation(attributes)
        end
      end

      def close_element(name, text)
        case name
        when "Pronunciation" then add_pronunciation(text)
        when "Definition" then add_definition(text)
        when "Example" then add_example(text)
        when "Synset" then @synset_rowid = nil
        end
      end

      # The specifier is `<id>:<version>`, as the `wn` package composes it, and
      # it is what Constants::WN_DB_VERSION names: a database whose lexicon
      # does not carry that exact string makes Base::Wordnet.open return nil
      # and lands the window on its "Database not found" page.
      def start_lexicon(attributes)
        attributes.fetch("version", "").then do |version|
          "#{attributes["id"]}:#{version}".then do |specifier|
            @specifiers << specifier
            execute(INSERT_LEXICON, [attributes["id"], attributes["label"], version, specifier])
            @lexicon_rowid = @database.last_insert_row_id
            report("Lexicon #{specifier} — #{attributes["label"]}")
          end
        end
      end

      def start_entry(attributes)
        unless @lexicon_rowid
          raise Error, "a LexicalEntry appeared before any Lexicon in #{@source}"
        end

        execute(INSERT_ENTRY, [@lexicon_rowid, attributes["id"]])
        @entry_rowid = @database.last_insert_row_id
        @form_rank = 0
        @entry_rank = 0
        tick(:entries)
      end

      # The lemma is the entry's rank-0 form, which is the one Base::Wordnet
      # reports as a synset's member and the one pronunciations hang off.
      def start_lemma(attributes) = add_form(attributes["writtenForm"])

      def start_form(attributes) = add_form(attributes["writtenForm"])

      def add_form(written_form)
        written_form.to_s.then do |form|
          execute(INSERT_FORM, [@entry_rowid, form, form.downcase, @form_rank])
          @form_rowid = @database.last_insert_row_id
          @form_rank += 1
        end
      end

      # WN-LMF puts the IPA in the element's text and the accent in its
      # `variety` attribute, uppercased ("US", "GB"); Base.matching_variety?
      # downcases both sides, so it is stored as written.
      def add_pronunciation(text)
        text.strip.then do |value|
          unless value.empty? || @form_rowid.nil?
            execute(INSERT_PRONUNCIATION, [@form_rowid, value, @variety])
          end
        end
      end

      # The synset is referenced by id and defined later in the document, so
      # the sense's synset_rowid is filled in by RESOLVE_SENSE_SYNSETS.
      def start_sense(attributes)
        execute(INSERT_SENSE, [attributes["id"], @entry_rowid, @entry_rank])
        @sense_rowid = @database.last_insert_row_id
        execute(STAGE_SENSE_SYNSET, [@sense_rowid, attributes["synset"]])
        @entry_rank += 1
        tick(:senses)
      end

      def start_synset(attributes)
        execute(INSERT_SYNSET, [@lexicon_rowid, attributes["id"], attributes["partOfSpeech"]])
        @synset_rowid = @database.last_insert_row_id
        tick(:synsets)
      end

      def add_definition(text)
        text.strip.then do |definition|
          unless definition.empty? || @synset_rowid.nil?
            execute(INSERT_DEFINITION, [@synset_rowid, definition])
          end
        end
      end

      def add_example(text)
        text.strip.then do |example|
          unless example.empty? || @synset_rowid.nil?
            execute(INSERT_EXAMPLE, [@synset_rowid, example])
          end
        end
      end

      def stage_sense_relation(attributes)
        execute(STAGE_SENSE_RELATION, [@sense_rowid, attributes["target"], attributes["relType"]])
      end

      def stage_synset_relation(attributes)
        execute(STAGE_SYNSET_RELATION, [@synset_rowid, attributes["target"], attributes["relType"]])
      end

      def execute(sql, binds) = statement(sql).execute!(*binds)

      def statement(sql) = @statements[sql] ||= @database.prepare(sql)

      def close_statements
        @statements.each_value(&:close)
        @statements.clear
      end

      def tick(counter)
        @counts[counter] += 1
        if (@counts[counter] % REPORT_EVERY).zero?
          report("#{@counts[counter]} #{counter}")
        end
      end

      def report(message)
        if @progress
          @progress.call(message)
        end
      end

      # `zstd-ruby` (the gem DatabaseManager#decompress unpacks with) in place
      # of shelling out to the `zstd` program: it vendors libzstd's C sources,
      # so building the database needs no system zstd either.
      def compress(db_path)
        FileUtils.mkdir_p(File.dirname(File.expand_path(@output)))
        report("Compressing #{size_in_mb(db_path)} MB at level #{@compression_level}")
        run_zstd(db_path)
        report("Wrote #{@output} — #{size_in_mb(@output)} MB")
      end

      def run_zstd(db_path)
        File.binwrite(@output, Zstd.compress(File.binread(db_path), level: @compression_level))
      rescue RuntimeError => e
        raise Error, "zstd-ruby failed to compress #{File.basename(@output)}: #{e.message}"
      end

      def size_in_mb(path) = (File.size(path) / (1024.0 * 1024.0)).round(1)
  end
end
