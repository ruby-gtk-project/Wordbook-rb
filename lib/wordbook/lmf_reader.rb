# frozen_string_literal: true

require "zlib"

module Wordbook
  # LmfReader is a streaming reader for the WN-LMF XML that Open English
  # WordNet publishes — the input half of upstream's
  # scripts/generate-wn-db.py, which hands the file to the `wn` package's own
  # loader (`wn.add`, subprojects/wn).
  #
  # Why this is hand-written rather than a call into an XML library: the
  # lexicon is 160 MB of XML and the app's runtime bundle (nix/Gemfile, the
  # gemspec) holds four gems — gtk4, adwaita, gettext and sqlite3. `rexml` is
  # not a default gem on Ruby 3.4 and is absent from this project's bundle, and
  # adding a parser the app never loads at runtime to the packaged closure to
  # run a build-time script once is the wrong trade. WN-LMF is also a narrow
  # dialect: no mixed content, no CDATA, no namespaced elements, no comments,
  # and every attribute value double-quoted. A scanner for that dialect is
  # smaller than the dependency.
  #
  # It is a scanner, not an XML parser, and the two places it is narrower than
  # XML are both deliberate:
  #
  #   * a `>` inside an attribute value is found by counting double quotes, so
  #     an attribute quoted with `'` and containing `>` would be misread.
  #     WN-LMF files from globalwordnet use `"` throughout, and every `>` in
  #     the 2025 lexicon is written `&gt;`.
  #   * `<?...?>`, `<!DOCTYPE ...>` and comments are skipped whole rather than
  #     interpreted.
  #
  # The buffer is held in ASCII-8BIT and only complete slices are re-tagged as
  # UTF-8: the stream is read in fixed-size chunks, which split multi-byte
  # characters, but every byte the scanner looks for (`<`, `>`, `"`) is ASCII
  # and UTF-8 is self-synchronising, so a slice taken at those boundaries is
  # always a whole sequence of characters.
  #
  # Events are yielded as they are met, two per element:
  #
  #   [:start, "Synset",     {"id" => "oewn-08242255-n", "partOfSpeech" => "n"}]
  #   [:end,   "Definition", "an urban, often lower-income inner-city area"]
  #
  # The string on an :end event is the character data since the element's own
  # start tag, unstripped; for an element with children it is the whitespace
  # after the last of them, which is why the caller strips it.
  class LmfReader
    # Raised when the document stops in the middle of a tag — a truncated
    # download, most often. Without it the scanner would sit forever on a `<`
    # it can never close.
    class TruncatedError < StandardError; end

    READ_SIZE = 256 * 1024

    ENTITIES = {
      "amp"  => "&",
      "lt"   => "<",
      "gt"   => ">",
      "quot" => '"',
      "apos" => "'",
    }.freeze

    # /n so the patterns match the ASCII-8BIT buffer: a UTF-8 regexp raised
    # Encoding::CompatibilityError on the first entry whose written form is not
    # ASCII.
    TAG = /\A(?<closing>\/?)(?<name>[A-Za-z_][A-Za-z0-9_.:-]*)(?<rest>.*?)(?<empty>\/?)\z/nm
    ATTRIBUTE = /(?<name>[A-Za-z_][A-Za-z0-9_.:-]*)\s*=\s*(?<quote>["'])(?<value>.*?)\k<quote>/nm
    REFERENCE = /&(?:(?<named>[a-zA-Z]+)|\#(?<decimal>[0-9]+)|\#x(?<hex>[0-9a-fA-F]+));/n

    # Reads `path`, gunzipping it when it is named .gz, and yields the reader to
    # the block. The stream is closed when the block returns.
    def self.open(path)
      if path.to_s.end_with?(".gz")
        Zlib::GzipReader.open(path) { |io| yield(new(io)) }
      else
        File.open(path, "rb") { |io| yield(new(io)) }
      end
    end

    def initialize(io)
      @io = io
      @buffer = String.new(encoding: Encoding::ASCII_8BIT)
      @text = String.new(encoding: Encoding::UTF_8)
      @eof = false
    end

    # Yields every start and end event in the document, in order.
    def each(&emit)
      until done?
        consume_text
        consume_markup(&emit)
      end
    end

    private

      def done? = @eof && @buffer.empty?

      # Everything up to the next `<` is character data; past the root element
      # there is no next `<` and what is left is the trailing newline.
      def consume_text
        index_of("<").then do |index|
          if index
            @text << decode(@buffer.slice!(0, index))
          else
            @buffer.clear
          end
        end
      end

      def consume_markup(&emit)
        markup.then do |source|
          if source
            dispatch(source, &emit)
          end
        end
      end

      # The `<...>` at the head of the buffer, with the brackets stripped, or
      # nil once the stream has run out.
      def markup
        markup_end.then do |index|
          if index
            @buffer.slice!(0, index + 1).then { |source| source.byteslice(1, source.bytesize - 2) }
          else
            unless @buffer.empty?
              raise TruncatedError, "document ends inside #{opening_fragment.inspect}"
            end
          end
        end
      end

      def opening_fragment = @buffer.byteslice(0, 80).force_encoding(Encoding::UTF_8).scrub

      # The offset of the `>` that closes the markup: the first one with an
      # even number of double quotes before it, so a `>` inside an attribute
      # value is passed over.
      def markup_end
        offset = 1
        found = nil
        while found.nil?
          index_of(">", offset).then do |index|
            if index.nil?
              found = false
            elsif quoted_evenly?(@buffer.byteslice(0, index))
              found = index
            else
              offset = index + 1
            end
          end
        end
        found || nil
      end

      def quoted_evenly?(source) = source.count('"').even?

      # The offset of `needle`, reading more of the stream until it is there or
      # the stream ends.
      def index_of(needle, offset = 0)
        until @buffer.index(needle, offset) || @eof
          read_chunk
        end
        @buffer.index(needle, offset)
      end

      def read_chunk
        @io.read(READ_SIZE).then do |chunk|
          if chunk
            @buffer << chunk
          else
            @eof = true
          end
        end
      end

      # A processing instruction, a doctype or a comment carries no event; a
      # `<name .../>` carries both of its element's events.
      def dispatch(source)
        if instruction?(source)
          @text.clear
        else
          TAG.match(source).then do |match|
            if match
              emit_element(match) { |*event| yield(*event) }
            end
          end
        end
      end

      def instruction?(source) = source.start_with?("?", "!")

      def emit_element(match)
        match[:name].dup.force_encoding(Encoding::UTF_8).then do |name|
          if match[:closing].empty?
            @text.clear
            yield(:start, name, attributes(match[:rest]))
            if match[:empty] == "/"
              yield(:end, name, "")
            end
          else
            yield(:end, name, @text.dup)
            @text.clear
          end
        end
      end

      def attributes(source)
        source.to_s.scan(ATTRIBUTE).each_with_object({}) do |(name, _quote, value), parsed|
          parsed[name.dup.force_encoding(Encoding::UTF_8)] = decode(value)
        end
      end

      def decode(source)
        source.dup.force_encoding(Encoding::UTF_8).then do |text|
          if text.include?("&")
            text.gsub(REFERENCE) { resolve(Regexp.last_match) }
          else
            text
          end
        end
      end

      # An unknown named entity is left as it was written: WN-LMF declares no
      # entities of its own, so dropping the text would lose a character the
      # file meant literally.
      def resolve(match)
        if match[:decimal]
          match[:decimal].to_i.chr(Encoding::UTF_8)
        elsif match[:hex]
          match[:hex].to_i(16).chr(Encoding::UTF_8)
        else
          ENTITIES.fetch(match[:named], match[0])
        end
      end
  end
end
