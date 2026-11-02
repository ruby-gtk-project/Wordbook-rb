# frozen_string_literal: true

module Wordbook
  # Constants carries the values upstream keeps in wordbook/constants.py.
  #
  # Upstream's `_define` helper exists because meson substitutes
  # `@WN_FILE_VERSION@` at install time and leaves the literal in place when
  # the module is imported from a source checkout. This port has no meson step,
  # so the same "unsubstituted means dev" rule is expressed as an environment
  # override with "dev" as the default.
  #
  module Constants
    RES_PATH = "/dev/mufeed/Wordbook"

    # The lexicon specifier the bundled database is built with: `id:version`,
    # which is what the `lexicons.specifier` column holds.
    WN_DB_VERSION = "oewn:2025+"
    WN_FILE_VERSION = ENV.fetch("WORDBOOK_WN_FILE_VERSION", "dev")

    # WordNet's one-letter part-of-speech tags. Several tags share a name, and
    # the order of the distinct names is the order the definition pages are
    # laid out in, so `POS_MAP.values.uniq` is what the result hash is keyed by.
    POS_MAP = {
      "s" => "adjective",
      "n" => "noun",
      "v" => "verb",
      "r" => "adverb",
      "a" => "adjective",
      "t" => "phrase",
      "c" => "conjunction",
      "p" => "adposition",
      "x" => "other",
      "u" => "unknown",
    }.freeze

    POS_NAMES = POS_MAP.values.uniq.freeze

    DARK_MODE_SENTENCE_COLOR = "cyan"
    LIGHT_MODE_SENTENCE_COLOR = "blue"

    # Stripped from both ends of a search term, then removed everywhere in it.
    SEARCH_TERM_CLEANUP_CHARS = '<>"-?`![](){}/:;,'
    SEARCH_TERM_REPLACE_CHARS = ["(", ")", "<", ">", "[", "]", "&", "\\", "\n"].freeze
  end
end
