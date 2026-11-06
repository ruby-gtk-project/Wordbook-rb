# frozen_string_literal: true

require "tmpdir"
require "zstd-ruby"

require "wordbook/database_manager"

RSpec.describe Wordbook::DatabaseManager do
  around do |example|
    Dir.mktmpdir("wordbook-db") do |dir|
      @dir = dir
      example.run
    end
  end

  # stub_const has to run inside the example, not around it, so the data
  # directory is pointed at the temporary one here.
  before { stub_const("Wordbook::Utils::DATA_DIR", @dir) }

  # The real zstd-ruby, so the extraction path under test is the one that
  # runs.
  def compress(source, target)
    File.binwrite(target, Zstd.compress(File.binread(source)))
  end

  def version_dir = File.join(@dir, "wn-#{Wordbook::Constants::WN_FILE_VERSION}")
  def db_path = File.join(version_dir, "wn.db")

  describe "the paths" do
    it "names the compressed database after the WordNet file version" do
      expect(described_class.filename).to eq("wn-#{Wordbook::Constants::WN_FILE_VERSION}.db.zst")
    end

    it "extracts into a directory of its own per version" do
      expect(described_class.version_dir).to eq(version_dir)
      expect(described_class.extracted_db_path).to eq(db_path)
    end
  end

  describe ".candidates" do
    it "looks in the meson build tree first, as upstream does" do
      allow(Wordbook::Utils).to receive(:glib_system_data_dirs).and_return(["/usr/share"])
      ENV["MESON_BUILD_ROOT"] = "/build"
      expect(described_class.candidates.first).to eq("/build/data/#{described_class.filename}")
    ensure
      ENV.delete("MESON_BUILD_ROOT")
    end

    it "looks in each system data directory under wordbook/" do
      allow(Wordbook::Utils).to receive(:glib_system_data_dirs).and_return(["/a", "/b"])
      expect(described_class.candidates).to eq(
        [
          "/a/wordbook/#{described_class.filename}",
          "/b/wordbook/#{described_class.filename}",
        ],
      )
    end
  end

  describe ".needs_extraction?" do
    it "is true when there is no extracted database" do
      expect(described_class.needs_extraction?).to be(true)
    end

    it "is false once one is in place" do
      FileUtils.mkdir_p(version_dir)
      File.write(db_path, "")
      expect(described_class.needs_extraction?).to be(false)
    end
  end

  describe ".old_version_dirs" do
    it "finds the wn- directories of other versions and leaves the current one" do
      %w[wn-dev wn-1 wn-2 other].each { |name| FileUtils.mkdir_p(File.join(@dir, name)) }
      File.write(File.join(@dir, "wn-3"), "a file, not a directory")
      expect(described_class.old_version_dirs("wn-dev").map { |path| File.basename(path) })
        .to contain_exactly("wn-1", "wn-2")
    end

    it "is empty when the data directory does not exist yet" do
      stub_const("Wordbook::Utils::DATA_DIR", File.join(@dir, "absent"))
      expect(described_class.old_version_dirs("wn-dev")).to eq([])
    end
  end

  describe ".cleanup_old_versions" do
    it "removes the other versions' directories" do
      FileUtils.mkdir_p(File.join(@dir, "wn-old"))
      FileUtils.mkdir_p(version_dir)
      described_class.cleanup_old_versions
      expect(Dir.children(@dir)).to contain_exactly(File.basename(version_dir))
    end
  end

  describe ".extract_database" do
    let(:compressed) { File.join(@dir, described_class.filename) }

    before do
      File.write(File.join(@dir, "payload"), "a database, for the purposes of this test")
      compress(File.join(@dir, "payload"), compressed)
    end

    it "decompresses into place" do
      expect(described_class.extract_database(compressed)).to be(true)
      expect(File.read(db_path)).to eq("a database, for the purposes of this test")
    end

    it "leaves no .tmp file behind on success" do
      described_class.extract_database(compressed)
      expect(File.exist?("#{db_path}.tmp")).to be(false)
    end

    it "reports a failure and removes the .tmp file when the archive is not one" do
      File.write(compressed, "not compressed at all")
      expect(described_class.extract_database(compressed)).to be(false)
      expect(File.exist?("#{db_path}.tmp")).to be(false)
      expect(File.exist?(db_path)).to be(false)
    end
  end

  describe ".setup" do
    it "is true without doing anything when the database is already extracted" do
      FileUtils.mkdir_p(version_dir)
      File.write(db_path, "")
      expect(described_class).not_to receive(:extract_database)
      expect(described_class.setup).to be(true)
    end

    it "is false when no compressed database is installed anywhere" do
      allow(Wordbook::Utils).to receive(:glib_system_data_dirs).and_return([@dir])
      expect(described_class.setup).to be(false)
    end

    it "prunes the old versions and extracts when one is installed" do
      File.write(File.join(@dir, "payload"), "db")
      FileUtils.mkdir_p(File.join(@dir, "wordbook"))
      FileUtils.mkdir_p(File.join(@dir, "wn-old"))
      compress(File.join(@dir, "payload"), File.join(@dir, "wordbook", described_class.filename))
      allow(Wordbook::Utils).to receive(:glib_system_data_dirs).and_return([@dir])

      expect(described_class.setup).to be(true)
      expect(File.read(db_path)).to eq("db")
      expect(File.exist?(File.join(@dir, "wn-old"))).to be(false)
    end
  end
end
