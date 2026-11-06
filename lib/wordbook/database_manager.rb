# frozen_string_literal: true

require "fileutils"
require "zstd-ruby"

require_relative "constants"
require_relative "utils"

module Wordbook
  # DatabaseManager finds the pre-built WordNet database shipped with the app,
  # extracts it into the user's data directory and removes the copies left by
  # earlier versions. A direct port of upstream's wordbook/database.py.
  #
  # Upstream: `wordbook/database.py:119` — `zstd.open`, from the Python
  # standard library.
  # Port: `decompress` below, streamed through `Zstd::StreamingDecompress`
  # (the `zstd-ruby` gem, which vendors libzstd's C sources — no system
  # `zstd` program or library needed). This closes FINDINGS.md defect 4: an
  # earlier round shelled out to the `zstd` program and told a user without
  # it installed "Database not found" about a complete installation.
  #
  module DatabaseManager
    CHUNK_SIZE = 1024 * 1024

    def self.filename = "wn-#{Constants::WN_FILE_VERSION}.db.zst"
    def self.version_dir = File.join(Utils::DATA_DIR, "wn-#{Constants::WN_FILE_VERSION}")
    def self.extracted_db_path = File.join(version_dir, "wn.db")

    # Searched in the order upstream searches: a meson build tree first, so a
    # development build uses the database it just generated, then the system
    # data directories an installed copy lives in.
    def self.find_compressed_db
      candidates.find { |path| File.file?(path) }.then do |path|
        if path
          Utils.log_info("Found compressed database: #{path}")
        else
          Utils.log_warning("No compressed database found for version #{Constants::WN_FILE_VERSION}")
        end
        path
      end
    end

    def self.candidates
      ENV["MESON_BUILD_ROOT"].then do |build_root|
        if build_root
          [File.join(build_root, "data", filename)]
        else
          []
        end
      end + Utils.glib_system_data_dirs.map { |dir| File.join(dir, "wordbook", filename) }
    end

    def self.needs_extraction?
      File.exist?(extracted_db_path).then do |exists|
        unless exists
          Utils.log_info("Database extraction needed for version #{Constants::WN_FILE_VERSION}")
        end
        !exists
      end
    end

    def self.cleanup_old_versions
      "wn-#{Constants::WN_FILE_VERSION}".then do |current|
        old_version_dirs(current).each do |dir|
          Utils.log_info("Removing old database version: #{dir}")
          begin
            FileUtils.rm_rf(dir, secure: true)
          rescue SystemCallError => e
            Utils.log_error("Failed to remove old database directory #{dir}: #{e.message}")
          end
        end
      end
    end

    def self.old_version_dirs(current)
      if File.directory?(Utils::DATA_DIR)
        Dir.children(Utils::DATA_DIR)
           .select { |name| name.start_with?("wn-") && name != current }
           .map { |name| File.join(Utils::DATA_DIR, name) }
           .select { |path| File.directory?(path) }
      else
        []
      end
    end

    # Extraction goes through a .tmp file that is renamed into place, so an
    # interrupted run never leaves a half-written database behind that the next
    # run would mistake for a complete one.
    def self.extract_database(compressed_path)
      tmp_path = "#{extracted_db_path}.tmp"
      begin
        FileUtils.mkdir_p(File.dirname(extracted_db_path))
        Utils.log_info("Extracting database from #{compressed_path} to #{tmp_path}")
        decompress(compressed_path, tmp_path)
        File.rename(tmp_path, extracted_db_path)
        Utils.log_info("Database extraction complete")
        true
      rescue StandardError => e
        Utils.log_error("Database extraction failed: #{e.message}")
        FileUtils.rm_f(tmp_path)
        false
      end
    end

    def self.decompress(compressed_path, tmp_path)
      decompressor = Zstd::StreamingDecompress.new
      File.open(tmp_path, "wb") do |out|
        File.open(compressed_path, "rb") do |input|
          out.write(decompressor.decompress(input.read(CHUNK_SIZE))) until input.eof?
        end
      end
    rescue RuntimeError => e
      raise "zstd-ruby failed to unpack #{File.basename(compressed_path)}: #{e.message}"
    end

    # The entry point the window's setup thread calls: true means there is a
    # usable database at extracted_db_path.
    def self.setup
      if needs_extraction?
        extract_if_available
      else
        Utils.log_info("Database already up to date")
        true
      end
    end

    def self.extract_if_available
      find_compressed_db.then do |compressed_db|
        if compressed_db
          cleanup_old_versions
          extract_database(compressed_db)
        else
          Utils.log_error("No compressed database found - installation may be incomplete")
          false
        end
      end
    end
  end
end
