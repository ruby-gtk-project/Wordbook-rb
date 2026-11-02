# frozen_string_literal: true

# kettle-jem:freeze
# To retain chunks of comments & code during kettle-jem templating:
# Wrap custom sections with freeze markers (e.g., as above and below this comment chunk).
# kettle-jem will then preserve content between those markers across template runs.
# kettle-jem:unfreeze

# wordbook-rb Rakefile v7.1.28 - 2026-10-11
# Ruby 2.3 (Safe Navigation) or higher required
#
# See LICENSE.md for license information.
#
# Copyright (c) 2026 ruby-gtk-project (github.com)
#
# Expected to work in any project that uses Bundler.
#
# Sets up tasks for appraisal2, floss_funding, kettle-jem, kettle-dev, rspec, minitest, rubocop_gradual, reek, yard, and stone_checksums.
#
# rake appraisal:install                      # Install Appraisal gemfiles (initial setup...
# rake appraisal:reset                        # Delete Appraisal lockfiles (gemfiles/*.gemfile.lock)
# rake appraisal:generate                     # Generate Appraisal gemfiles without resolving...
# rake appraisal:update                       # Generate and update Appraisal gemfiles
# rake bench                                  # Run all benchmarks (alias for bench:run)
# rake bench:list                             # List available benchmark scripts
# rake bench:run                              # Run all benchmark scripts (skips on CI)
# rake build:generate_checksums               # Generate both SHA256 & SHA512 checksums i...
# rake bundle:audit:check                     # Checks the Gemfile.lock for insecure depe...
# rake bundle:audit:update                    # Updates the bundler-audit vulnerability d...
# rake ci:act[opt]                            # Run 'act' with a selected workflow
# rake coverage                               # Run specs w/ coverage and open results in...
# rake default                                # Default tasks aggregator
# rake install                                # Build and install wordbook-rb-1.0.0.gem in...
# rake install:local                          # Build and install wordbook-rb-1.0.0.gem in...
# rake kettle:jem:install                     # Internal target used by `kettle-jem install`
# rake kettle:jem:selftest                    # Self-test: template wordbook-rb against itse...
# rake kettle:jem:template                    # Internal target used by scoped `kettle-jem template --only`
# rake reek                                   # Check for code smells
# rake reek:update                            # Run reek and store the output into the RE...
# rake release[remote]                        # Create tag v1.0.0 and build and push kett...
# rake rubocop_gradual                        # Run RuboCop Gradual
# rake rubocop_gradual:autocorrect            # Run RuboCop Gradual with autocorrect (onl...
# rake rubocop_gradual:autocorrect_all        # Run RuboCop Gradual with autocorrect (saf...
# rake rubocop_gradual:check                  # Run RuboCop Gradual to check the lock file
# rake rubocop_gradual:force_update           # Run RuboCop Gradual to force update the l...
# rake rubocop_gradual_debug                  # Run RuboCop Gradual
# rake rubocop_gradual_debug:autocorrect      # Run RuboCop Gradual with autocorrect (onl...
# rake rubocop_gradual_debug:autocorrect_all  # Run RuboCop Gradual with autocorrect (saf...
# rake rubocop_gradual_debug:check            # Run RuboCop Gradual to check the lock file
# rake rubocop_gradual_debug:force_update     # Run RuboCop Gradual to force update the l...
# rake spec                                   # Run RSpec code examples
# rake test                                   # Run tests
# rake yard                                   # Generate YARD Documentation
# rake yard:lint                              # Lint YARD Documentation
#

# simplecov:disable
require "bundler/gem_tasks" if !Dir[File.join(__dir__, "*.gemspec")].empty?
# simplecov:enable

# Define a base default task early so other files can enhance it.
desc "Default tasks aggregator"
task :default do
  puts "Default task complete."
end

# Without this, a generated docs/ directory makes Rake resolve the bare
# name `docs` as an up-to-date file task, so `rake docs` exits 0 having
# regenerated nothing.
desc "Generate YARD documentation"
task docs: "yard"

# simplecov:disable
### MONOREPO FAMILY TASKS
if Dir.exist?(File.join(__dir__, "gems"))
  def family_gem_dirs
    Dir.glob(File.join(__dir__, "gems", "*", "*.gemspec"))
      .map { |path| File.dirname(path) }
      .uniq
      .sort_by { |path| File.basename(path) }
  end

  def run_kettle_family(*args)
    sh("bundle", "exec", "kettle-family", *args)
  end

  namespace :family do
    desc "List released Ruby subgems"
    task :list do
      family_gem_dirs.each { |path| puts File.basename(path) }
    end

    desc "Run release readiness checks for the Ruby gem family"
    task :readiness do
      run_kettle_family("check")
    end

    desc "Run tests for the Ruby gem family"
    task :test do
      run_kettle_family("test", "--execute")
    end

    desc "Run lint for the Ruby gem family"
    task :lint do
      run_kettle_family("lint", "--execute")
    end

    desc "Generate YARD docs for the Ruby gem family"
    task :docs do
      run_kettle_family("docs", "--execute")
    end

    desc "Report release state for the Ruby gem family"
    task :release_state do
      run_kettle_family("release-state")
    end

    desc "Run the Ruby gem family release planner"
    task :release do
      run_kettle_family("release")
    end

    desc "Execute the Ruby gem family release"
    task :release_execute do
      run_kettle_family("release", "--execute")
    end
  end
end
# simplecov:enable

# External gems that define tasks - add here!
begin
  require "kettle/dev"
  Kettle::Dev.install_tasks unless Kettle::Dev::RUNNING_AS == "rake"
rescue LoadError
  warn("NOTE: kettle-dev isn't installed, or is disabled for #{RUBY_VERSION} in the current environment")
end

### TEMPLATING TASKS
# These tasks are installed for the `kettle-jem` executable. Run full templating
# through `kettle-jem install`; use `kettle-jem template --only PATH` only for
# scoped file updates. The executable prepares the environment and then
# delegates here when rake orchestration is needed.
kettle_jem_selftest_unavailable_note = nil
begin
  require "kettle/jem"
  if Kettle::Jem.respond_to?(:install_tasks)
    Kettle::Jem.install_tasks
  else
    kettle_jem_selftest_unavailable_note = "NOTE: kettle-jem #{Kettle::Jem::Version::VERSION} does not provide rake tasks in this environment"
  end
rescue LoadError
  kettle_jem_selftest_unavailable_note = "NOTE: kettle-jem isn't installed, or is disabled for #{RUBY_VERSION} in the current environment"
end

if kettle_jem_selftest_unavailable_note
  desc("(stub) kettle:jem:selftest is unavailable")
  task("kettle:jem:selftest") do
    warn(kettle_jem_selftest_unavailable_note)
  end
end

### RELEASE TASKS
# Setup stone_checksums
begin
  require "stone_checksums"
rescue LoadError
  desc("(stub) build:generate_checksums is unavailable")
  task("build:generate_checksums") do
    warn("NOTE: stone_checksums isn't installed, or is disabled for #{RUBY_VERSION} in the current environment")
  end
end

### PROFILES
# Upstream's meson `profile` option (meson.build:40-50): the stable build's
# application id is dev.mufeed.Wordbook, a development build's is
# dev.mufeed.Wordbook.Devel, and the search provider's object path moves with
# it. `rake install:data PROFILE=development` installs the development copy;
# flake.nix's packages.devel is the same decision made in the packaging.
APP_BASE_ID = "dev.mufeed.Wordbook"
DEVELOPMENT_PROFILE = ENV.fetch("PROFILE", "") == "development"
# A helper rather than three `if` expressions assigned to constants: the house
# style forbids conditional assignment, and a constant cannot be assigned
# inside an `if` branch without warning when the file is loaded twice.
def profile_choice(development, stable) = DEVELOPMENT_PROFILE ? development : stable

APP_ID = profile_choice("#{APP_BASE_ID}.Devel", APP_BASE_ID)
SEARCH_PROVIDER_OBJECT_PATH = profile_choice(
  "/dev/mufeed/Wordbook/Devel/SearchProvider",
  "/dev/mufeed/Wordbook/SearchProvider",
)
APP_ICON_SOURCE = profile_choice(
  "data/icons/dev.mufeed.Wordbook.Devel.svg",
  "data/icons/dev.mufeed.Wordbook.svg",
)

### TRANSLATION TASKS
# po/ is upstream's donated catalogue — 15 languages, no fuzzies — carried
# across unchanged. Nothing here rewrites a .po except rmsgmerge through
# gettext:po:update, which is run only when the message set genuinely changes.
#
# The domain is `wordbook`, from upstream's po/meson.build. The locales come
# from po/LINGUAS rather than from Dir["po/*.po"], so a language that loses its
# file loses it loudly.
#
# Two things here are not the gem's defaults, and both were defects:
#
# 1. The gem's layout is po/<locale>/<domain>.po. The port ships upstream's
#    flat po/<locale>.po, so `rake gettext:mo:update` invented po/de/wordbook.po
#    with 53 empty msgstrs and compiled THAT over the good catalogue — fifteen
#    languages silently emptied, exit status zero. FlatLayoutTask below points
#    every po path at po/<locale>.po.
# 2. The extractor globbed lib/**/*.rb + exe/*, while po/POTFILES also names
#    data/dev.mufeed.Wordbook.desktop.in and data/*.metainfo.xml.in — so
#    `rake gettext:pot:create` dropped every desktop-entry and metainfo string
#    (Dark Mode, Favorites, Features:, Fully offline, Light Mode,
#    Pronunciations, Random Word, dictionary;, Double click to search,
#    Dark mode, the AppStream summary) and chaining pot:create into po:update
#    would have merged those out of all fifteen catalogues. POTFILES is now the
#    single list, and the two data/*.in files are extracted with GNU xgettext's
#    Desktop reader and its metainfo ITS rules.
POT_DOMAIN = "wordbook"
POTFILES = "po/POTFILES"

# The files POTFILES names, split by which extractor can read them.
def potfiles_entries
  File.readlines(POTFILES, chomp: true)
      .reject { |line| line.empty? || line.start_with?("#") }
end

def potfiles_ruby = potfiles_entries.grep_v(/\.in\z/)
def potfiles_desktop = potfiles_entries.grep(/\.desktop\.in\z/)
def potfiles_metainfo = potfiles_entries.grep(/\.metainfo\.xml\.in\z/)

# GNU gettext ships metainfo.its, the ITS rules that tell xgettext which
# AppStream elements are translatable. Its directory moved between gettext
# releases (share/gettext/its and share/gettext-<ver>/its both exist in the
# wild), so it is located relative to the xgettext on PATH.
def gettext_its_dir
  ENV["WORDBOOK_ITS_DIR"] ||
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
       .map { |dir| File.join(dir, "xgettext") }
       .find { |candidate| File.executable?(candidate) }
       .then do |xgettext|
      if xgettext.nil?
        raise "xgettext is not on PATH; it extracts the data/*.in messages"
      end

      File.expand_path("../..", xgettext).then do |prefix|
        Dir.glob(
          File.join(
            prefix,
            "share",
            "gettext*",
            "its",
            "metainfo.its",
          ),
        )
           .first
           .then do |rules|
          if rules.nil?
            raise "no metainfo ITS rules found under #{prefix}/share/gettext*/its"
          end

          File.dirname(rules)
        end
      end
    end
end

# The template the fifteen catalogues are merged against. Written through
# msgcat so the three extractors' output is one file with one header.
def create_pot(pot_file_path)
  require "fileutils"
  require "tmpdir"

  Dir.mktmpdir("wordbook-pot") do |tmp|
    parts = []

    File.join(tmp, "ruby.pot").tap do |part|
      GetText::Tools::XGetText.run(
        "--output",
        part,
        "--package-name",
        POT_DOMAIN,
        "--add-comments=Translators",
        *potfiles_ruby,
      )
      parts << part
    end

    potfiles_desktop.each_with_index do |file, index|
      File.join(tmp, "desktop#{index}.pot").tap do |part|
        sh(
          "xgettext",
          "--language=Desktop",
          "--from-code=UTF-8",
          "--add-comments=Translators",
          "--package-name=#{POT_DOMAIN}",
          "--output=#{part}",
          file,
        )
        parts << part
      end
    end

    potfiles_metainfo.each_with_index do |file, index|
      File.join(tmp, "metainfo#{index}.pot").tap do |part|
        sh(
          "xgettext",
          "--its=#{File.join(gettext_its_dir, "metainfo.its")}",
          "--from-code=UTF-8",
          "--add-comments=Translators",
          "--package-name=#{POT_DOMAIN}",
          "--output=#{part}",
          file,
        )
        parts << part
      end
    end

    FileUtils.mkdir_p(File.dirname(pot_file_path.to_s))
    sh(
      "msgcat",
      "--sort-by-file",
      "--output=#{pot_file_path}",
      *parts,
    )
  end
end

begin
  require "gettext/tools/task"

  # The gem's Path puts a catalogue at po/<locale>/<domain>.po. Upstream's — and
  # so this port's — is the flat po/<locale>.po that meson's i18n module reads.
  class FlatLayoutTask < GetText::Tools::Task
    class FlatPath < GetText::Tools::Task::Path
      def po_directory = po_base_directory
      def po_file = po_base_directory + "#{locale}.po"
      def po_time_stamp_file = po_base_directory + "#{locale}.po.time_stamp"
      def edit_po_file = po_base_directory + "#{locale}.edit.po"
    end

    private

      def create_path(locale = nil)
        FlatPath.new(
          Pathname.new(po_base_directory),
          Pathname.new(mo_base_directory),
          domain,
          locale&.to_s,
        )
      end
  end

  FlatLayoutTask.define do |task|
    task.domain = POT_DOMAIN
    task.package_name = POT_DOMAIN
    task.package_version = Module.new.tap { |mod|
      Kernel.load("#{__dir__}/lib/wordbook/rb/version.rb", mod)
    }::Wordbook::Rb::Version::VERSION
    # POTFILES is the list, not a glob: the extractor and the file the
    # translation platform reads cannot drift apart if there is only one list.
    task.files = potfiles_entries
    task.po_base_directory = "po"
    task.mo_base_directory = "locale"
    task.locales = File.read("po/LINGUAS").split
    task.pot_creator = method(:create_pot)
  end
rescue LoadError
  desc("(stub) gettext:mo:update is unavailable")
  task("gettext:mo:update") do
    warn("NOTE: the gettext gem isn't installed in the current environment")
  end
end

# `rake locale` — the catalogues the running app reads, compiled with GNU
# msgfmt straight from po/<lang>.po.
#
# This exists because `locale/` was gitignored and built by a task that
# emptied it: a clone of this branch showed the sidebar title as "History" in
# all fifteen languages. The compiled catalogues are committed now as well, so
# a `git archive` of HEAD is translated without running anything; this task is
# what keeps them in step after a .po changes, and bin/setup and the devShell
# both call it.
desc "Compile po/<lang>.po into locale/<lang>/LC_MESSAGES/#{POT_DOMAIN}.mo with GNU msgfmt"
task :locale do
  require "fileutils"

  File.read("po/LINGUAS").split.each do |lang|
    File.join("locale", lang, "LC_MESSAGES").then do |dir|
      FileUtils.mkdir_p(dir)
      sh(
        "msgfmt",
        "--check",
        "--output-file=#{File.join(dir, "#{POT_DOMAIN}.mo")}",
        "po/#{lang}.po",
      )
    end
  end
end

### DATA TASKS
namespace :data do
  # The three tests upstream declares in data/meson.build:36, :58 and :76 and
  # runs in CI (.github/workflows/CI.yml:26). Nothing in this port ran any of
  # them, which mattered more here than upstream: this port does the @app-id@
  # substitution and the msgfmt --desktop/--xml merges by hand, so the files
  # being validated are ones it generates rather than ones meson generates.
  #
  # The files are built into tmp/validate first, because a validator run over
  # a template full of @app-id@ proves nothing about what gets installed.
  desc "Validate the generated desktop entry, metainfo and GSettings schema (upstream's three meson tests)"
  task :validate do
    require "fileutils"

    "tmp/validate".tap do |dir|
      FileUtils.rm_rf(dir)
      FileUtils.mkdir_p(File.join(dir, "schemas"))

      File.write(
        File.join(dir, "#{APP_ID}.desktop.in"),
        File.read("data/#{APP_BASE_ID}.desktop.in").gsub("@app-id@", APP_ID),
      )
      sh(
        "msgfmt",
        "--desktop",
        "--template=#{File.join(dir, "#{APP_ID}.desktop.in")}",
        "-d",
        "po",
        "-o",
        File.join(dir, "#{APP_ID}.desktop"),
      )

      File.write(
        File.join(dir, "#{APP_ID}.metainfo.xml.in"),
        File.read("data/#{APP_BASE_ID}.metainfo.xml.in").gsub("@app-id@", APP_ID),
      )
      sh(
        "msgfmt",
        "--xml",
        "--template=#{File.join(dir, "#{APP_ID}.metainfo.xml.in")}",
        "-d",
        "po",
        "-o",
        File.join(dir, "#{APP_ID}.metainfo.xml"),
      )

      File.write(
        File.join(dir, "schemas", "#{APP_ID}.gschema.xml"),
        File.read("data/schemas/#{APP_BASE_ID}.gschema.xml.in").gsub("@app-id@", APP_ID),
      )

      sh("desktop-file-validate", File.join(dir, "#{APP_ID}.desktop"))
      sh(
        "appstreamcli",
        "validate",
        "--no-net",
        File.join(dir, "#{APP_ID}.metainfo.xml"),
      )
      sh(
        "glib-compile-schemas",
        "--strict",
        "--dry-run",
        File.join(dir, "schemas"),
      )
    end
  end
end

### DATA INSTALLATION
# The desktop entry, the metainfo, the icons and the GNOME Shell search
# provider files have to land in XDG locations for the app to have a launcher,
# an icon, an entry in Software and a search provider the shell knows about.
# `rake install:data` does that for a user-level install; flake.nix does the
# same thing for the packaged build.
#
# The desktop entry and the metainfo are translated here rather than at build
# time: GNU msgfmt merges po/ into them (`--desktop` and `--xml`), which is
# what meson's i18n.merge_file does for upstream. The @app-id@, @APP_ID@ and
# @object_path@ substitutions are what meson's configure_file does.
namespace :install do
  desc "Install the desktop entry, metainfo, icons, schema and search provider files under PREFIX (default ~/.local)"
  task :data do
    prefix = ENV.fetch("PREFIX", File.expand_path("~/.local"))
    share = File.join(prefix, "share")
    require "fileutils"

    FileUtils.mkdir_p(
      [
        File.join(share, "applications"),
        File.join(share, "metainfo"),
        File.join(share, "icons/hicolor/scalable/apps"),
        File.join(share, "icons/hicolor/symbolic/apps"),
        File.join(share, "gnome-shell/search-providers"),
        File.join(share, "dbus-1/services"),
        File.join(share, "glib-2.0/schemas"),
        "tmp/install",
      ],
    )

    File.write(
      "tmp/install/#{APP_ID}.desktop.in",
      File.read("data/#{APP_BASE_ID}.desktop.in").gsub("@app-id@", APP_ID),
    )
    sh(
      "msgfmt",
      "--desktop",
      "--template=tmp/install/#{APP_ID}.desktop.in",
      "-d",
      "po",
      "-o",
      File.join(share, "applications/#{APP_ID}.desktop"),
    )

    File.write(
      "tmp/install/#{APP_ID}.metainfo.xml.in",
      File.read("data/#{APP_BASE_ID}.metainfo.xml.in").gsub("@app-id@", APP_ID),
    )
    sh(
      "msgfmt",
      "--xml",
      "--template=tmp/install/#{APP_ID}.metainfo.xml.in",
      "-d",
      "po",
      "-o",
      File.join(share, "metainfo/#{APP_ID}.metainfo.xml"),
    )

    FileUtils.cp(APP_ICON_SOURCE, File.join(share, "icons/hicolor/scalable/apps/#{APP_ID}.svg"))
    FileUtils.cp(
      "data/icons/#{APP_BASE_ID}-symbolic.svg",
      File.join(share, "icons/hicolor/symbolic/apps/#{APP_BASE_ID}-symbolic.svg"),
    )

    File.write(
      File.join(share, "gnome-shell/search-providers/#{APP_ID}.SearchProvider.ini"),
      File.read("data/#{APP_BASE_ID}.SearchProvider.ini")
          .gsub("@APP_ID@", APP_ID)
          .gsub("@object_path@", SEARCH_PROVIDER_OBJECT_PATH),
    )
    File.write(
      File.join(share, "dbus-1/services/#{APP_ID}.SearchProvider.service"),
      File.read("data/#{APP_BASE_ID}.SearchProvider.service.in")
          .gsub("@APP_ID@", APP_ID)
          .gsub("@bindir@", File.join(prefix, "bin")),
    )

    File.write(
      File.join(share, "glib-2.0/schemas/#{APP_ID}.gschema.xml"),
      File.read("data/schemas/#{APP_BASE_ID}.gschema.xml.in").gsub("@app-id@", APP_ID),
    )
    sh("glib-compile-schemas", File.join(share, "glib-2.0/schemas"))

    # The dictionary, when `rake wn:db` has built one. Upstream installs it
    # into pkgdatadir — <datadir>/wordbook — which is where
    # Wordbook::DatabaseManager.candidates looks for it
    # (data/meson.build:4-16). It is optional here for the same reason it is
    # optional upstream: the archive is a 60 MB build product, not a file in
    # the tree, and `-Dinstall_wn_db=false` is upstream's way of installing
    # without one.
    Dir["data/wn-*.db.zst"].each do |archive|
      File.join(share, "wordbook").then do |dir|
        FileUtils.mkdir_p(dir)
        FileUtils.cp(archive, File.join(dir, File.basename(archive)))
      end
    end

    # The compiled catalogues, where bindtextdomain's last candidate looks for
    # them. `rake locale` is what builds them.
    Rake::Task[:locale].invoke
    File.read("po/LINGUAS").split.each do |lang|
      "locale/#{lang}/LC_MESSAGES/#{POT_DOMAIN}.mo".then do |mo|
        File.join(
          share,
          "locale",
          lang,
          "LC_MESSAGES",
        ).then do |dir|
          FileUtils.mkdir_p(dir)
          FileUtils.cp(mo, File.join(dir, "#{POT_DOMAIN}.mo"))
        end
      end
    end
  end
end

### THE WORDNET DATABASE
# Upstream builds the dictionary itself as a meson `custom_target` gated on
# `-Dinstall_wn_db` (data/meson.build:4-16): scripts/generate-wn-db.py
# downloads the Open English WordNet lexicon, loads it with the vendored `wn`
# package and writes `wn-<version>.db.zst` into pkgdatadir. The port's
# equivalent is exe/wordbook-generate-db — Wordbook::DatabaseBuilder — and this
# task is the `custom_target`: one command, the default output name
# Wordbook::DatabaseManager hunts for, and `install:data` picking it up.
namespace :wn do
  desc "Build data/wn-<version>.db.zst from the Open English WordNet lexicon (downloads ~13 MB)"
  task :db do
    sh(
      RbConfig.ruby,
      "-Ilib",
      "exe/wordbook-generate-db",
      *ENV.fetch("WN_DB_ARGS", "").split,
    )
  end
end
