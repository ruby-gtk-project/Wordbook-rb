# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "about_dialog"
require_relative "base"
require_relative "espeak"
require_relative "profile"
require_relative "rb/version"
require_relative "settings"
require_relative "shortcuts_dialog"
require_relative "style"
require_relative "translations"
require_relative "utils"
require_relative "window"

module Wordbook
  # Application manages the window, the application-wide actions and the
  # command line, ported from upstream's wordbook/main.py.
  #
  # I replaced GLib's option parser with a hand-written one. The first version
  # of it mis-read `wordbook --look-up` with no term (it searched for the empty
  # string) and mis-read a search term spelled like a flag, because I wrote a
  # paragraph calling that a deliberate difference instead of writing the code.
  # The parser below consumes arguments by position, so `--look-up -i` looks up
  # the term "-i" and a missing term is reported rather than searched; GOption
  # does both of those.
  # Upstream: `wordbook/main.py:43-74` — four `add_main_option` entries, parsed
  # by GOption. Port: `parse` below.
  #
  # The application is an `Adwaita::Application`, as upstream's is
  # (`main.py:20`): the constructor takes the application id and the flags
  # positionally. The stylesheet is installed from Style rather than loaded out
  # of a gresource bundle, which this port does not build — so the icons that
  # upstream finds through the resource base path are found through the icon
  # theme instead, from the SVGs in data/icons; see COMPONENT_PARITY.md.
  #
  # SIGINT and SIGTERM are trapped with Ruby's own Signal.trap rather than with
  # GLib.unix_signal_add.
  #
  class Application
    include Translations

    # Follows the profile: `dev.mufeed.Wordbook.Devel` for a development build,
    # as upstream's `application_id` does (meson.build:43-49).
    APP_ID = Profile.app_id
    APP_NAME = N_("Wordbook")

    # The accelerators the application installs. The shortcuts dialog does not
    # read this table: its rows name their action and Adwaita resolves the
    # accelerator from here, as upstream's do.
    #
    # `app.shortcuts` is an addition: upstream's main.py binds no accelerator
    # for it, so <Primary>question is a key combination this port answers and
    # upstream does not. Recorded in COMPONENT_PARITY.md.
    APP_ACCELS = {
      "app.quit"            => ["<Primary>q"],
      "app.shortcuts"       => ["<Primary>question"],
      "win.quit"            => ["<Primary>w"],
      "win.search-selected" => ["<Primary>s"],
      "win.random-word"     => ["<Primary>r"],
      "win.paste-search"    => ["<Primary><Shift>v"],
      "win.preferences"     => ["<Primary>comma"],
      "win.toggle-sidebar"  => ["F9"],
      "win.toggle-menu"     => ["F10"],
    }.freeze

    APP_ACTIONS = %w[about shortcuts quit].freeze

    OPTIONS = {
      "--look-up"    => :look_up,
      "-l"           => :look_up,
      "--info"       => :info,
      "-i"           => :info,
      "--verbose"    => :verbose,
      "-v"           => :verbose,
      "--auto-paste" => :auto_paste,
      "-p"           => :auto_paste,
    }.freeze

    def initialize(
      app_id: APP_ID,
      version: Rb::VERSION,
      development_mode: Profile.development?,
      settings: Settings.get
    )
      @app_id = app_id
      @version = version
      @development_mode = development_mode
      @settings = settings
      @options = {}
      Base.create_required_dirs
    end

    def build
      app.tap do |application|
        application.signal_connect("startup") { on_startup }
        application.signal_connect("command-line") { |_app, command_line| on_command_line(command_line) }
        application.signal_connect("activate") { on_activate }
        application.signal_connect("shutdown") { on_shutdown }

        %w[INT TERM].each { |signal| Signal.trap(signal) { application.quit } }
      end
    end

    def run(argv = ARGV) = build.run([$PROGRAM_NAME] + argv)

    # The command line is handled here rather than by GApplication's default
    # because the options can act on an already-running instance.
    def app = @app ||= Adwaita::Application.new(@app_id, :handles_command_line)

    def window
      @window ||= Window.new(
        app,
        term:                 @options[:look_up],
        auto_paste_requested: @options[:auto_paste] == true,
        settings:             @settings,
        development_mode:     @development_mode,
      )
    end

    private

      def on_startup
        app.resource_base_path = Constants::RES_PATH
        GLib.application_name = _(APP_NAME)
        GLib.prgname = @app_id
        Translations.bind_glib_domain
        Style.install
        Adwaita::StyleManager.default.color_scheme = color_scheme
        setup_actions
      end

      def color_scheme
        if @settings.gtk_dark_ui
          Adwaita::ColorScheme::FORCE_DARK
        else
          Adwaita::ColorScheme::DEFAULT
        end
      end

      def on_activate
        unless @built
          window.build
          @built = true
        end
        window.present
      end

      # Upstream's do_command_line: --info prints the versions and exits, and
      # the rest either acts on the open window or is remembered for the one
      # about to be built.
      def on_command_line(command_line)
        @options = parse(command_line.arguments.drop(1))
        Utils.log_init(@development_mode || @options[:verbose] == true)
        if @options[:error]
          report_option_error(command_line)
        else
          act_on_options
        end
      end

      # GOption exits non-zero on a malformed option rather than carrying on
      # with a half-parsed one, so this does too.
      def report_option_error(command_line)
        command_line.printerr("#{@options[:error]}\n")
        1
      end

      def act_on_options
        if @options[:info]
          print_version_info
        else
          activate_with_options
        end
        0
      end

      def activate_with_options
        if @built
          apply_options_to_window
        end
        app.activate
      end

      def apply_options_to_window
        if @options[:look_up].to_s.empty?
          if @options[:auto_paste]
            window.queue_auto_paste
          end
        else
          window.trigger_search(@options[:look_up])
        end
      end

      def print_version_info
        Espeak.version_info(@version).each { |line| $stdout.puts(line) }
      end

      # Upstream's four options, short forms included. --look-up takes the next
      # argument, or anything after an "=" in the same one; that argument is
      # consumed, so a term spelled like a flag is still a term, and a
      # --look-up with nothing after it is an error rather than a search for
      # the empty string.
      def parse(arguments)
        {}.tap do |options|
          index = 0
          while index < arguments.length
            index = consume(arguments, index, options)
          end
        end
      end

      # Returns the index to continue from, which is how the value of
      # --look-up is skipped rather than parsed as a flag of its own.
      def consume(arguments, index, options)
        arguments[index].then do |argument|
          case OPTIONS.fetch(argument.split("=").first, nil)
          when :look_up then take_term(
            arguments,
            index,
            options,
            argument,
          )
          when nil then index + 1
          else flag(OPTIONS.fetch(argument), options, index)
          end
        end
      end

      def flag(name, options, index)
        options[name] = true
        index + 1
      end

      def take_term(arguments, index, options, argument)
        if argument.include?("=")
          options[:look_up] = argument.split("=", 2).last
          index + 1
        else
          take_next_term(
            arguments,
            index,
            options,
            argument,
          )
        end
      end

      def take_next_term(arguments, index, options, argument)
        arguments[index + 1].then do |value|
          if value.nil?
            options[:error] = "Missing argument for #{argument}"
          else
            options[:look_up] = value
          end
          index + 2
        end
      end

      def setup_actions
        APP_ACTIONS.each { |name| app.add_action(action(name)) }
        APP_ACCELS.each { |name, accels| app.set_accels_for_action(name, accels) }
      end

      def action(name)
        Gio::SimpleAction.new(name).tap do |simple_action|
          simple_action.signal_connect("activate") { activate_action(name) }
        end
      end

      def activate_action(name)
        case name
        when "about" then show_about
        when "shortcuts" then show_shortcuts
        when "quit" then app.quit
        end
      end

      def show_about
        AboutDialog.new(@app_id, @version).tap do |dialog|
          dialog.build
          dialog.present(window.window)
        end
      end

      def show_shortcuts
        ShortcutsDialog.new.tap do |dialog|
          dialog.build
          dialog.present(window.window)
        end
      end

      def on_shutdown
        if @built
          window.save_state
        end
      end
  end
end
