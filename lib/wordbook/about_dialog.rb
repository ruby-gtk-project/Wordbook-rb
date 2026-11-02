# frozen_string_literal: true

require "adwaita"

module Wordbook
  # AboutDialog is the about window, ported from on_about in upstream's
  # wordbook/main.py.
  #
  # The upstream metadata is kept as it is — this is still Wordbook, by the
  # same author, under the same licence — with the port's own repository added
  # as a second link so the code being run can be found.
  #
  class AboutDialog < Adwaita::AboutDialog
    APP_NAME = "Wordbook"
    COMMENTS = "Look up definitions for words"
    DEVELOPER = "Mufeed Ali"
    COPYRIGHT = "Copyright © 2016-2026 Mufeed Ali"
    WEBSITE = "https://apps.gnome.org/Wordbook"
    UPSTREAM_SOURCE = "https://github.com/mufeedali/Wordbook"
    ISSUE_URL = "https://github.com/mufeedali/Wordbook/issues"
    PORT_SOURCE = "https://github.com/ruby-gtk-project/Wordbook-rb"

    def initialize(application_icon, version)
      super()
      @application_icon = application_icon
      @version = version
    end

    def build
      tap do |about|
        about.application_icon = @application_icon
        about.application_name = APP_NAME
        about.version = @version
        about.comments = COMMENTS
        about.developer_name = DEVELOPER
        about.translator_credits = "translator-credits"
        about.license_type = Gtk::License::GPL_3_0
        about.website = WEBSITE
        about.issue_url = ISSUE_URL
        about.copyright = COPYRIGHT
        about.add_link("Source Code", UPSTREAM_SOURCE)
        about.add_link("Ruby Port", PORT_SOURCE)
      end
    end
  end
end
