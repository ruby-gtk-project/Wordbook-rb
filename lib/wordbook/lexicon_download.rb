# frozen_string_literal: true

require "fileutils"
require "net/http"
require "uri"

require_relative "database_builder"

module Wordbook
  # LexiconDownload fetches the WN-LMF lexicon DatabaseBuilder reads, the port
  # of `download_wordnet_xml` in upstream's scripts/generate-wn-db.py.
  #
  # Upstream tries each URL in turn and reports the percentage every ten
  # percent; this does the same, and adds following redirects, which
  # urllib.request does on its own and Net::HTTP does not — the second of
  # upstream's two URLs answers with a 301.
  module LexiconDownload
    class Error < StandardError; end

    CHUNK_SIZE = 1024 * 1024
    MAX_REDIRECTS = 5
    USER_AGENT = "Wordbook"

    # Downloads the first URL that answers, into `path`. Returns the path, and
    # raises when every URL has failed, so a build never carries on with half a
    # lexicon.
    def self.fetch(path, urls: DatabaseBuilder::SOURCE_URLS, progress: nil)
      FileUtils.mkdir_p(File.dirname(File.expand_path(path)))
      urls.each do |url|
        report(progress, "Downloading from #{url}...")
        download(url, path, progress)
        report(progress, "Downloaded to #{path}")
        break
      rescue StandardError => e
        report(progress, "Download failed: #{e.message}")
        FileUtils.rm_f(path)
      end
      unless File.file?(path)
        raise Error, "every source URL failed: #{urls.join(", ")}"
      end

      path
    end

    def self.download(url, path, progress)
      response_for(URI.parse(url)) do |response|
        File.open(path, "wb") { |file| stream(response, file, progress) }
      end
    end

    # Opens the URL, following redirects, and yields the response whose body is
    # still unread so it can be streamed.
    def self.response_for(uri, redirects = MAX_REDIRECTS, &block)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(Net::HTTP::Get.new(uri, "User-Agent" => USER_AGENT)) do |response|
          case response
          when Net::HTTPRedirection
            follow(
              uri,
              response,
              redirects,
              &block
            )
          when Net::HTTPSuccess then block.call(response)
          else raise Error, "#{uri} answered #{response.code} #{response.message}"
          end
        end
      end
    end

    def self.follow(uri, response, redirects, &block)
      unless redirects.positive?
        raise Error, "too many redirects from #{uri}"
      end

      response_for(URI.join(uri, response["location"]), redirects - 1, &block)
    end

    # Reports every ten percent, as upstream's `percent // 10 > last // 10`
    # does, and nothing at all when the server sent no Content-Length.
    def self.stream(response, file, progress)
      total = response["Content-Length"].to_i
      downloaded = 0
      decade = -1
      response.read_body do |chunk|
        file.write(chunk)
        downloaded += chunk.bytesize
        percent(downloaded, total).then do |reached|
          if reached && reached > decade
            decade = reached
            report(progress, "Download: #{reached * 10}%")
          end
        end
      end
    end

    def self.percent(downloaded, total)
      if total.positive?
        (downloaded * 100 / total) / 10
      end
    end

    def self.report(progress, message)
      if progress
        progress.call(message)
      end
    end
  end
end
