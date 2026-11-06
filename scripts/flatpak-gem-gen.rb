#!/usr/bin/env ruby
# frozen_string_literal: true

# Ported from upstream's scripts/flatpak-wheel-gen.py. Upstream resolves and
# pins Python wheels for build-aux/flatpak/dev.mufeed.Wordbook.Devel.json's
# "python3-modules" module so the flatpak build runs with no network; this is
# the Ruby equivalent for a gem dependency, pinning one specific version's
# `.gem` file (and its sha256) as a flatpak "file" source.
#
# Usage:
#   ruby scripts/flatpak-gem-gen.rb GEM_NAME VERSION [GEM_NAME VERSION ...]
#   ruby scripts/flatpak-gem-gen.rb --gemspec   # resolve every runtime
#                                                # dependency in
#                                                # wordbook-rb.gemspec at its
#                                                # currently installed version
#
# Prints a JSON array of flatpak "file" sources to stdout, each with the
# gem's download URL and its sha256 — the shape the manifest's "sources"
# array expects for a module that installs gems from pinned local files
# instead of `bundle install --share=network`.
#
# This needs network access to rubygems.org to run (it downloads each gem to
# compute its sha256); it is not run as part of `rake` or the spec suite, and
# the committed manifest does not depend on its output — it still installs
# gems with `--share=network` at build time, which is this port's honestly
# documented divergence from upstream's fully offline wheel pinning (see
# COMPONENT_PARITY.md). This script exists so pinning sources for an offline
# build is one command away, the same job upstream's wheel-gen script does.

require "json"
require "net/http"
require "digest"
require "tmpdir"
require "fileutils"

RUBYGEMS_API = "https://rubygems.org/api/v1/versions"
RUBYGEMS_DOWNLOAD = "https://rubygems.org/downloads"

GemSpecLookupError = Class.new(StandardError)

def gemspec_runtime_dependencies(path)
  spec = Gem::Specification.load(path)
  unless spec
    raise GemSpecLookupError, "could not load #{path}"
  end

  spec.runtime_dependencies
end

def resolved_version_for(name, requirement)
  spec = Gem.loaded_specs[name] || Gem::Specification.find_by_name(name, requirement)
  spec.version.to_s
end

def gem_sha256(name, version)
  Dir.mktmpdir do |dir|
    dest = File.join(dir, "#{name}-#{version}.gem")
    uri = URI("#{RUBYGEMS_DOWNLOAD}/#{name}-#{version}.gem")
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Get.new(uri)
      http.request(request) do |response|
        unless response.code == "200"
          raise GemSpecLookupError, "#{uri}: HTTP #{response.code}"
        end

        File.open(dest, "wb") do |file|
          response.read_body { |chunk| file.write(chunk) }
        end
      end
    end
    Digest::SHA256.file(dest).hexdigest
  end
end

def flatpak_source_for(name, version)
  {
    "type"          => "file",
    "url"           => "#{RUBYGEMS_DOWNLOAD}/#{name}-#{version}.gem",
    "sha256"        => gem_sha256(name, version),
    "dest-filename" => "#{name}-#{version}.gem",
  }
end

def pairs_from_gemspec
  gemspec_path = File.join(__dir__, "..", "wordbook-rb.gemspec")
  gemspec_runtime_dependencies(gemspec_path).map do |dependency|
    [dependency.name, resolved_version_for(dependency.name, dependency.requirement)]
  end
end

def pairs_from_argv(argv)
  argv.each_slice(2).map { |name, version| [name, version] }
end

if $PROGRAM_NAME == __FILE__
  if ARGV == ["--gemspec"]
    pairs = pairs_from_gemspec
  else
    pairs = pairs_from_argv(ARGV)
  end

  if pairs.empty?
    warn "usage: #{$PROGRAM_NAME} GEM_NAME VERSION [GEM_NAME VERSION ...] | --gemspec"
    exit(1)
  end

  sources = pairs.map { |name, version| flatpak_source_for(name, version) }
  puts JSON.pretty_generate(sources)
end
