# frozen_string_literal: true

require "json"
require "fileutils"

require_relative "utils"

module Wordbook
  # PronunciationAccent is upstream's enum of the same name
  # (wordbook/settings.py): the espeak-ng accent codes, their display names,
  # and the index each one has in the preferences combo row.
  class PronunciationAccent
    attr_reader :code, :display_name

    def initialize(code, display_name)
      @code = code
      @display_name = display_name
    end

    US = new("us", "American English")
    GB = new("gb", "British English")
    ALL = [US, GB].freeze

    def self.codes = ALL.map(&:code)
    def self.display_names = ALL.map(&:display_name)
    def self.from_code(code) = ALL.find { |accent| accent.code == code } || US
    def self.from_index(index) = ALL.fetch(index.to_i, US)
    def self.valid_code?(code) = codes.include?(code)

    def index = ALL.index(self)
    def ==(other) = other.is_a?(PronunciationAccent) && other.code == code
    alias eql? ==
    def hash = code.hash
  end

  # Settings manages the application's configuration, ported from upstream's
  # wordbook/settings.py.
  #
  # Upstream reaches for pydantic to validate a three-section JSON file
  # (behavior, appearance, state) under XDG_CONFIG_HOME, and saves on every
  # property write. The file format and the two validators pydantic enforces —
  # an unknown accent code falls back to "us", and the stored history is
  # truncated to its last HISTORY_LIMIT entries — are reproduced here without
  # the dependency, so a config file written by either implementation is
  # readable by the other.
  #
  class Settings
    HISTORY_LIMIT = 20

    DEFAULTS = {
      "behavior"   => {
        "live_search"           => true,
        "double_click"          => false,
        "pronunciations_accent" => "us",
        "auto_paste_on_launch"  => false,
      },
      "appearance" => {
        "force_dark_mode" => false,
      },
      "state"      => {
        "history"       => [],
        "favorites"     => [],
        "window_width"  => 400,
        "window_height" => 600,
      },
    }.freeze

    # Upstream's Settings.get() singleton. The window, the preferences dialog
    # and the search provider all read the same instance.
    def self.get = @instance ||= new

    def initialize(path: Utils::CONFIG_FILE)
      @path = path
      @autosave = false
      @values = load_values
      @autosave = true
    end

    def location = @path

    # --- Behaviour ----------------------------------------------------------

    def live_search = @values["behavior"]["live_search"]
    def live_search=(value)
      store("behavior", "live_search", value == true)
    end

    def double_click = @values["behavior"]["double_click"]
    def double_click=(value)
      store("behavior", "double_click", value == true)
    end

    def auto_paste_on_launch = @values["behavior"]["auto_paste_on_launch"]
    def auto_paste_on_launch=(value)
      store("behavior", "auto_paste_on_launch", value == true)
    end

    def pronunciations_accent = PronunciationAccent.from_code(@values["behavior"]["pronunciations_accent"])
    def pronunciations_accent=(accent)
      store("behavior", "pronunciations_accent", accent.code)
    end

    # --- Appearance ---------------------------------------------------------

    def gtk_dark_ui = @values["appearance"]["force_dark_mode"]
    def gtk_dark_ui=(value)
      store("appearance", "force_dark_mode", value == true)
    end

    # --- State --------------------------------------------------------------

    # A copy, as upstream returns: callers iterate it while the window keeps
    # mutating its own list store.
    def history = @values["state"]["history"].dup
    def history=(terms)
      store("state", "history", Array(terms).map(&:to_s))
    end
    def clear_history = store("state", "history", [])

    def favorites = @values["state"]["favorites"].dup
    def favorites=(terms)
      store("state", "favorites", Array(terms).map(&:to_s))
    end

    def add_favorite(term)
      favorites.then do |terms|
        unless terms.include?(term)
          store("state", "favorites", terms + [term])
        end
      end
    end

    def remove_favorite(term)
      favorites.then do |terms|
        if terms.include?(term)
          store("state", "favorites", terms - [term])
        end
      end
    end

    def favorite?(term) = @values["state"]["favorites"].include?(term)

    def window_width = @values["state"]["window_width"]
    def window_width=(value)
      store("state", "window_width", value.to_i)
    end

    def window_height = @values["state"]["window_height"]
    def window_height=(value)
      store("state", "window_height", value.to_i)
    end

    # --- Bulk operations ----------------------------------------------------

    # Upstream's batch_update: apply several settings, write the file once.
    # Keys name the accessors, so this is what window.save_state hands over.
    def batch_update(updates)
      @autosave = false
      begin
        updates.each { |key, value| apply(key, value) }
      ensure
        @autosave = true
      end
      save
    end

    def reset_to_defaults
      Utils.log_info("Resetting settings to defaults")
      @values = deep_copy(DEFAULTS)
      save
    end

    private

      def apply(key, value)
        setter = :"#{key}="
        if respond_to?(setter)
          public_send(setter, value)
        else
          Utils.log_warning("Attempted to set unknown setting: #{key}")
        end
      end

      def store(section, key, value)
        @values[section][key] = value
        if @autosave
          save
        end
        value
      end

      def save
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, "#{JSON.pretty_generate(@values, indent: "    ")}\n")
        Utils.log_debug("Settings saved successfully")
      rescue SystemCallError => e
        Utils.log_error("Failed to save settings: #{e.message}")
      end

      def load_values
        if File.exist?(@path)
          @values = validate(merged(read))
          Utils.log_info("Loaded settings from JSON configuration")
        else
          @values = deep_copy(DEFAULTS)
          save
        end
        @values
      end

      # Missing sections and missing keys both fall back to the defaults, which
      # is what pydantic's `default_factory` gives upstream.
      def merged(stored)
        deep_copy(DEFAULTS).merge!(stored) { |_section, defaults, values| defaults.merge(values) }
      end

      def read
        JSON.parse(File.read(@path)).select { |section, values| DEFAULTS.key?(section) && values.is_a?(Hash) }
      rescue JSON::ParserError, SystemCallError => e
        Utils.log_error("Failed to load JSON settings: #{e.message}")
        Utils.log_info("Creating default settings")
        {}
      end

      # The two checks pydantic performs for upstream.
      def validate(values)
        values.tap do |data|
          unless PronunciationAccent.valid_code?(data["behavior"]["pronunciations_accent"])
            data["behavior"]["pronunciations_accent"] = PronunciationAccent::US.code
          end
          data["state"]["history"] = Array(data["state"]["history"]).map(&:to_s).last(HISTORY_LIMIT)
          data["state"]["favorites"] = Array(data["state"]["favorites"]).map(&:to_s)
        end
      end

      def deep_copy(hash) = hash.transform_values { |section| section.transform_values(&:dup) }
  end
end
