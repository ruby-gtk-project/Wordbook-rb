# frozen_string_literal: true

require "glib2"
require "logger"
require "fileutils"

module Wordbook
  # Utils holds the project-wide paths and the logger, ported from upstream's
  # wordbook/utils.py.
  #
  # Upstream's log helpers each append the current traceback when they are
  # called from inside an `except` block. Ruby's equivalent of
  # `sys.exc_info()[0]` is `$!`, which is set for the duration of a `rescue`
  # body, so the same "log the backtrace when there is one" behaviour falls out
  # of checking it.
  #
  module Utils
    # GLib.user_config_dir and friends are what upstream uses. They are checked
    # for rather than assumed because the paths are read at load time, and the
    # XDG variables they are defined in terms of are the right fallback.
    def self.glib_dir(method, env_key, default)
      if GLib.respond_to?(method)
        GLib.public_send(method)
      else
        ENV.fetch(env_key, File.expand_path(default))
      end
    end

    def self.glib_system_data_dirs
      if GLib.respond_to?(:system_data_dirs)
        GLib.system_data_dirs
      else
        ENV.fetch("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
      end
    end

    CONFIG_DIR = File.join(glib_dir(:user_config_dir, "XDG_CONFIG_HOME", "~/.config"), "wordbook")
    CONFIG_FILE = File.join(CONFIG_DIR, "wordbook.json")
    DATA_DIR = File.join(glib_dir(:user_data_dir, "XDG_DATA_HOME", "~/.local/share"), "wordbook")

    LOGGER = Logger.new($stderr).tap do |logger|
      logger.level = Logger::WARN
      logger.formatter = proc do |severity, time, _progname, message|
        format(
          "%<time>s - [%<severity>s] [%<thread>s] %<message>s\n",
          time:     time.strftime("%Y-%m-%d %H:%M:%S,%L"),
          severity: severity,
          thread:   Thread.current.name || Thread.current.object_id.to_s(16),
          message:  message,
        )
      end
    end

    # Upstream's log_init: debug runs chatty, everything else only warns.
    def self.log_init(debug)
      if debug
        LOGGER.level = Logger::DEBUG
      else
        LOGGER.level = Logger::WARN
      end
    end

    def self.log_debug(message) = log(Logger::DEBUG, message)
    def self.log_info(message) = log(Logger::INFO, message)
    def self.log_warning(message) = log(Logger::WARN, message)
    def self.log_error(message) = log(Logger::ERROR, message)
    def self.log_critical(message) = log(Logger::FATAL, message)

    def self.log(level, message)
      LOGGER.add(level, message)
      $!.then do |error|
        if error
          LOGGER.add(level, "#{error.class}: #{error.message}\n#{Array(error.backtrace).join("\n")}")
        end
      end
    end

    # Upstream's `accessibility { label: … }` in the .blp files, which is what
    # a screen reader announces for a button whose only visible content is an
    # icon.
    #
    # GTK's own API is varargs in C; introspection exposes
    # gtk_accessible_update_property as
    # `(n_properties, properties[], values[])`, and ruby-gnome drops the length
    # argument, so the properties and the values are passed as arrays. The
    # signature was read out of the Gtk-4.0 typelib rather than run: GTK cannot
    # be initialised in the environment this was written in (FINDINGS.md,
    # defect 5), so no screen reader has announced any of these five labels.
    def self.set_accessible_label(widget, label)
      widget.update_property([Gtk::AccessibleProperty::LABEL], [label])
    end

    # Upstream makes these in base.create_required_dirs; the paths live here, so
    # the mkdir does too, and base delegates.
    def self.create_required_dirs(*extra)
      ([CONFIG_DIR, DATA_DIR] + extra).each { |dir| FileUtils.mkdir_p(dir) }
    end
  end
end
