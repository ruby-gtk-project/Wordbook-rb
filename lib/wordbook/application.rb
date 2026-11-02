# frozen_string_literal: true

require "gtk4"
require "adwaita"

require_relative "about_dialog"
require_relative "base"
require_relative "espeak"
require_relative "rb/version"
require_relative "settings"
require_relative "shortcuts_dialog"
require_relative "style"
require_relative "utils"
require_relative "window"

module Wordbook
  # Application manages the window, the application-wide actions and the
  # command line, ported from upstream's wordbook/main.py.
  #
  # Three deliberate differences:
  #
  #   * Adwaita::Application is unusable from Ruby, so this is a
  #     Gtk::Application. Adwaita's style manager is still what sets the colour
  #     scheme, and the stylesheet is installed from Style rather than loaded
  #     from a gresource bundle, which this port does not build.
  #   * the four command line options are parsed from the argument vector
  #     instead of being declared with add_main_option and read back out of a
  #     GLib::VariantDict — the same flags, including their short forms.
  #   * SIGINT and SIGTERM are trapped with Ruby's own Signal.trap rather than
  #     with GLib.unix_signal_add.
  #
  class Application
    APP_ID = "dev.mufeed.Wordbook"
    APP_NAME = "Wordbook"

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

    def initialize(app_id: APP_ID, version: Rb::VERSION, development_mode: false, settings: Settings.get)
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

    # Gtk's application, because Adwaita's is broken in these bindings. The
    # command line is handled here rather than by GApplication's default
    # because the options can act on an already-running instance.
    def app = @app ||= Gtk::Application.new(@app_id, :handles_command_line)

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
        GLib.application_name = APP_NAME
        GLib.prgname = @app_id
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
      # argument, or anything after an "=" in the same one.
      def parse(arguments)
        arguments.each_with_object({}) do |argument, options|
          OPTIONS.fetch(argument.split("=").first, nil).then do |name|
            record(
              options,
              name,
              argument,
              arguments,
            )
          end
        end
      end

      def record(options, name, argument, arguments)
        case name
        when :look_up then options[:look_up] = value_for(argument, arguments)
        when nil then nil
        else options[name] = true
        end
      end

      def value_for(argument, arguments)
        if argument.include?("=")
          argument.split("=", 2).last
        else
          arguments[arguments.index(argument) + 1].to_s
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
