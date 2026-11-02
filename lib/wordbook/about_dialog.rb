# frozen_string_literal: true

require "adwaita"

require_relative "translations"

module Wordbook
  # AboutDialog is the about window, ported from on_about in upstream's
  # wordbook/main.py.
  #
  # The upstream metadata is kept as it is: this is still Wordbook, by the same
  # author, under the same licence.
  #
  # `add_link(_("Ruby Port"), …)` below is a string upstream does not have, so
  # none of the fifteen catalogues has ever been offered it and it renders in
  # English in every language. It is an addition this port made and has not
  # proposed upstream; see TRANSLATION_PARITY.md, "Keys the port adds".
  #
  class AboutDialog < Adwaita::AboutDialog
    include Translations

    APP_NAME = N_("Wordbook")
    COMMENTS = N_("Look up definitions for words")
    DEVELOPER = "Mufeed Ali"
    COPYRIGHT = N_("Copyright © 2016-2026 Mufeed Ali")
    WEBSITE = "https://apps.gnome.org/Wordbook"
    UPSTREAM_SOURCE = "https://github.com/mufeedali/Wordbook"
    ISSUE_URL = "https://github.com/mufeedali/Wordbook/issues"
    PORT_SOURCE = "https://github.com/ruby-gtk-project/Wordbook-rb"

    # An added key: upstream has no second link, so this msgid is in none of
    # the fifteen catalogues. Recorded in TRANSLATION_PARITY.md under the keys
    # the port adds, and not yet proposed upstream.
    PORT_LINK_LABEL = N_("Ruby Port")

    def initialize(application_icon, version)
      super()
      @application_icon = application_icon
      @version = version
    end

    def build
      tap do |about|
        about.application_icon = @application_icon
        about.application_name = _(APP_NAME)
        about.version = @version
        about.comments = _(COMMENTS)
        about.developer_name = DEVELOPER
        about.translator_credits = _("translator-credits")
        about.license_type = Gtk::License::GPL_3_0
        about.website = WEBSITE
        about.issue_url = ISSUE_URL
        about.copyright = _(COPYRIGHT)
        about.add_link(_("Source Code"), UPSTREAM_SOURCE)
        about.add_link(_(PORT_LINK_LABEL), PORT_SOURCE)
      end
    end
  end
end
