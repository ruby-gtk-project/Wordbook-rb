# frozen_string_literal: true

# Reports facts about a freshly built window that can only be observed in a
# process of its own, as one JSON object on stdout.
#
# Two of them cannot be driven from inside test/drive_wordbook.rb:
#
#   * The display language. gettext resolves LANGUAGE once, when the text
#     domain is bound at load time, so a translated string can only be seen by
#     a process that was started with LANGUAGE set. The port shipped for a
#     round with locale/ gitignored, which made a clone English in all fifteen
#     languages while the working tree looked translated; the only check that
#     would have caught it is this one, run with LANGUAGE=de.
#   * The profile. lib/wordbook/profile.rb reads WORDBOOK_PROFILE at load
#     time, as upstream's meson resolves `-Dprofile=development` at configure
#     time, so the `devel` CSS class on the window can only be seen in a
#     process started with it set.
#
# Run it the way test/drive_wordbook.rb runs it:
#
#   LANGUAGE=de nix develop --command xvfb-run -a ruby test/probe_window.rb

require "json"
require "tmpdir"

ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("wordbook-probe-config")
ENV["XDG_DATA_HOME"] = Dir.mktmpdir("wordbook-probe-data")

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "wordbook"

Wordbook::Application.new(
  app_id:           Wordbook::Profile.app_id,
  development_mode: Wordbook::Profile.development?,
).then do |application|
  # A process that never reaches "activate" — a GApplication that registered as
  # a remote instance, say — would hang whoever is waiting for this output, so
  # it ends itself either way.
  GLib::Timeout.add_seconds(60) do
    warn("probe_window: no window after 60s")
    application.app.quit
    false
  end

  # Connected before Application#build adds its own "activate" handler, so the
  # inner timeout is scheduled first and fires after the window has been built
  # and laid out.
  application.app.signal_connect("activate") do
    GLib::Timeout.add(400) do
      $stdout.puts(
        JSON.generate(
          "app_id"             => application.app.application_id,
          "profile"            => Wordbook::Profile.name,
          "object_path"        => Wordbook::Profile.object_path,
          "locale_dir"         => Wordbook::Translations::LOCALE_DIR,
          "window_css_classes" => application.window.window.css_classes,
          "sidebar_title"      => application.window.sidebar.window_title.title,
          "filter_tooltip"     => application.window.sidebar.favorites_filter_button.tooltip_text,
          "clear_tooltip"      => application.window.sidebar.clear_history_button.tooltip_text,
        ),
      )
      $stdout.flush
      application.app.quit
      false
    end
  end

  exit(application.run([]))
end
