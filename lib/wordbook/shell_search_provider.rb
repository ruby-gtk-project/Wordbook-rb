# frozen_string_literal: true

require "gtk4"
require "securerandom"

require_relative "base"
require_relative "database_manager"
require_relative "utils"

module Wordbook
  # ShellSearchProvider exposes definitions to the GNOME Shell overview search.
  #
  # Ported from upstream's data/search_provider.in and the file that registers
  # it, data/dev.mufeed.Wordbook.SearchProvider.ini. It implements
  # org.gnome.Shell.SearchProvider2:
  #
  #   GetInitialResultSet(as)       -> as      ids for the matched terms
  #   GetSubsearchResultSet(as, as) -> as      the same, for the narrowed query
  #   GetResultMetas(as)            -> aa{sv}  id/name/description per result
  #   ActivateResult(s, as, u)                 opens the app on that term
  #   LaunchSearch(as, u)                      opens the app
  #
  # Like upstream it is a service of its own rather than part of the running
  # app: the shell starts it on demand, it reads the same bundled database, and
  # opening a result spawns the application binary with --look-up.
  #
  # Upstream keys its results with a fresh UUID per search and reports the
  # lemma as each result's `id` meta, so the identifier the shell hands back to
  # ActivateResult is the lemma rather than the UUID. Both are accepted here.
  #
  class ShellSearchProvider
    APP_ID = "dev.mufeed.Wordbook"
    INTERFACE = "org.gnome.Shell.SearchProvider2"
    BUS_NAME = "#{APP_ID}.SearchProvider"
    OBJECT_PATH = "/dev/mufeed/Wordbook/SearchProvider"
    DEFAULT_BINARY = "wordbook"

    NODE_XML = <<~XML
      <node>
        <interface name="org.gnome.Shell.SearchProvider2">
          <method name="GetInitialResultSet">
            <arg type="as" name="terms" direction="in"/>
            <arg type="as" name="results" direction="out"/>
          </method>
          <method name="GetSubsearchResultSet">
            <arg type="as" name="previous_results" direction="in"/>
            <arg type="as" name="terms" direction="in"/>
            <arg type="as" name="results" direction="out"/>
          </method>
          <method name="GetResultMetas">
            <arg type="as" name="identifiers" direction="in"/>
            <arg type="aa{sv}" name="metas" direction="out"/>
          </method>
          <method name="ActivateResult">
            <arg type="s" name="identifier" direction="in"/>
            <arg type="as" name="terms" direction="in"/>
            <arg type="u" name="timestamp" direction="in"/>
          </method>
          <method name="LaunchSearch">
            <arg type="as" name="terms" direction="in"/>
            <arg type="u" name="timestamp" direction="in"/>
          </method>
        </interface>
      </node>
    XML

    INACTIVITY_TIMEOUT = 10_000

    # Runs the provider as the standalone service the .ini points the shell at:
    # a Gio::Application owning the bus name, registering the object on the
    # connection it gets at startup, and exiting once the shell has been quiet
    # for INACTIVITY_TIMEOUT — the same shape upstream's service has.
    def self.run(binary: DEFAULT_BINARY)
      new(binary: binary).then do |provider|
        Gio::Application.new(BUS_NAME, :is_service).tap do |app|
          app.inactivity_timeout = INACTIVITY_TIMEOUT
          app.signal_connect("startup") { provider.register(app.dbus_connection) }
          app.signal_connect("activate") { nil }
          app.run([])
        end
      end
    end

    def initialize(binary: DEFAULT_BINARY, wordnet: nil)
      @binary = binary
      @wordnet = wordnet
      @results = {}
    end

    def register(connection)
      interface_info.then do |interface|
        connection.register_object(OBJECT_PATH, interface, method(:handle_method_call))
      end
    rescue StandardError, GLib::Error => e
      warn "Could not register the search provider: #{e.message}"
      nil
    end

    # lookup_interface rather than interfaces.first: Gio::DBusNodeInfo#interfaces
    # returns unusable strings in these bindings.
    def interface_info = Gio::DBusNodeInfo.new(NODE_XML).lookup_interface(INTERFACE)

    # --- Interface methods ---------------------------------------------------

    # Each term is looked up on its own, and the first synset of every part of
    # speech it has becomes a result, which is what upstream reports.
    def initial_result_set(terms)
      @results = {}
      Array(terms).each { |term| collect(term.to_s) }
      @results.keys
    end

    def subsearch_result_set(_previous_results, terms) = initial_result_set(terms)

    def result_metas(ids)
      Array(ids).filter_map { |id| @results[id.to_s] }.map { |result| meta_for(result) }
    end

    def activate_result(identifier, _terms, _timestamp) = launch(["--look-up", term_for(identifier)])
    def launch_search(_terms, _timestamp) = launch([])

    private

      def collect(term)
        definition(term).then do |result|
          if result
            result.each_value do |synsets|
              unless synsets.empty?
                remember(synsets.first)
              end
            end
          end
        end
      rescue StandardError => e
        Utils.log_error("Error while searching, WordNet is probably not available yet: #{e.message}")
        warn "Error while searching, WordNet is probably not downloaded yet."
      end

      def definition(term)
        wordnet.then do |instance|
          if instance
            Base.get_definition(term, instance)[:result]
          end
        end
      end

      def remember(synset)
        @results[SecureRandom.uuid] = { name: synset[:name], definition: synset[:definition] }
      end

      # Opened lazily, so the shell's own startup of this service costs nothing
      # until something is typed into the overview.
      def wordnet
        unless @wordnet
          if DatabaseManager.setup
            @wordnet = Base.wordnet
          end
        end
        @wordnet
      end

      def meta_for(result)
        {
          "id"          => result[:name].to_s,
          "name"        => result[:name].to_s,
          "description" => result[:definition].to_s,
        }
      end

      def term_for(identifier)
        @results[identifier.to_s].then do |result|
          if result
            result[:name].to_s
          else
            identifier.to_s
          end
        end
      end

      # Detached, so the provider can be reaped by the shell while the window
      # it opened keeps running.
      def launch(arguments)
        Process.detach(Process.spawn(@binary, *arguments))
      rescue SystemCallError => e
        Utils.log_error("Could not launch #{@binary}: #{e.message}")
        nil
      end

      def handle_method_call(_connection, _sender, _path, _interface, method_name, parameters, invocation)
        case method_name
        when "GetInitialResultSet"
          invocation.return_value(string_array(initial_result_set(parameters.get_child_value(0).to_a)))
        when "GetSubsearchResultSet"
          invocation.return_value(
            string_array(
              subsearch_result_set(
                parameters.get_child_value(0).to_a,
                parameters.get_child_value(1).to_a,
              ),
            ),
          )
        when "GetResultMetas"
          invocation.return_value(metas_variant(result_metas(parameters.get_child_value(0).to_a)))
        when "ActivateResult"
          activate_result(parameters.get_child_value(0).get_string, [], 0)
          invocation.return_value(nil)
        when "LaunchSearch"
          launch_search(parameters.get_child_value(0).to_a, 0)
          invocation.return_value(nil)
        else
          invocation.return_dbus_error("#{INTERFACE}.UnknownMethod", "Unknown method #{method_name}")
        end
      rescue StandardError => e
        invocation.return_dbus_error("#{INTERFACE}.Error", e.message)
      end

      # Reply variants are built by parsing GVariant text: GLib::Variant.new
      # raises NotImplementedError for a{sv} in these bindings, and cannot
      # build the tuple a D-Bus reply needs either.
      def string_array(values)
        GLib::Variant.parse("([#{values.map { |value| quote(value) }.join(", ")}],)", "(as)")
      end

      def metas_variant(metas) = GLib::Variant.parse("(#{metas_text(metas)},)", "(aa{sv})")
      def metas_text(metas) = "[#{metas.map { |meta| meta_text(meta) }.join(", ")}]"

      def meta_text(meta)
        "{#{meta.map { |key, value| "#{quote(key)}: <#{quote(value)}>" }.join(", ")}}"
      end

      # GVariant text format uses C's string escapes. The block form of gsub is
      # deliberate: backslashes in a replacement string are themselves
      # interpreted.
      ESCAPES = { "\\" => "\\\\", '"' => '\\"' }.freeze

      def quote(value) = %("#{value.to_s.gsub(/[\\"]/) { |char| ESCAPES.fetch(char) }}")
  end
end
