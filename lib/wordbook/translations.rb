# frozen_string_literal: true

require "gettext"

require_relative "utils"

module Wordbook
  # Translations binds the port to upstream's message catalogue and hands out
  # the gettext markers the rest of the port uses.
  #
  # Ported from upstream's `from gettext import gettext as _` (wordbook/main.py:5
  # and wordbook/window.py:9) together with blueprint's `_()` and `C_()`, which
  # the three .blp files use and which the compiler turns into the same calls.
  #
  # The domain is `wordbook`, which is what `i18n.gettext('wordbook')` in
  # upstream's po/meson.build declares. A `.mo` is found at
  # `<path>/<lang>/LC_MESSAGES/<domain>.mo`, so the domain *is* the filename:
  # renaming it to `wordbook-rb` would orphan all fifteen of upstream's
  # catalogues and the 780 strings in them.
  #
  # `include GetText` binds a text domain to a class rather than to the
  # process, so this module includes and binds once and every class that has
  # strings includes it; the lookup is found through the ancestor chain.
  # `included` also extends the including class, so a class body — which is
  # where the menu and shortcut tables live — can call the markers while the
  # class is still being defined.
  #
  module Translations
    TEXT_DOMAIN = "wordbook"

    # Searched in this order: an explicit override, the catalogues committed
    # under locale/ and rebuilt by `rake locale`, then the XDG data directories
    # an installed copy's `.mo` files live in. Omitting `path:` would make the
    # lookup depend on the working directory and silently find nothing when the
    # app is started from its desktop file.
    #
    # `rake locale` and not `rake gettext:mo:update`: this comment named the
    # latter for a round, and that task compiled po/<locale>/wordbook.po — a
    # file the gem invents, with every msgstr empty — over the good catalogue,
    # so following the instruction in this comment emptied all fifteen
    # languages and exited zero. The Rakefile's FlatLayoutTask now points the
    # gem at po/<locale>.po, so gettext:mo:update is safe too; `rake locale` is
    # the one that only ever runs GNU msgfmt.
    def self.locale_dir
      candidates.find { |dir| Dir.exist?(dir) } || candidates.last
    end

    def self.candidates
      [
        ENV["WORDBOOK_LOCALE_DIR"],
        File.expand_path("../../locale", __dir__),
        *Utils.glib_system_data_dirs.map { |dir| File.join(dir, "locale") },
      ].compact
    end

    LOCALE_DIR = locale_dir

    include GetText

    bindtextdomain(TEXT_DOMAIN, path: LOCALE_DIR)

    # The desktop entry and the metainfo are translated by GLib and AppStream
    # from the same catalogue, through libintl rather than through the gem, so
    # the domain has to be bound on that side too.
    def self.bind_glib_domain
      GLib::GetText.bindtextdomain(TEXT_DOMAIN, LOCALE_DIR)
    rescue NameError, NoMethodError => e
      Utils.log_warning("Could not bind the GLib text domain: #{e.message}")
      nil
    end

    def self.included(base)
      base.extend(self)
      super
    end
  end
end
