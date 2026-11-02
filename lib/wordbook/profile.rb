# frozen_string_literal: true

module Wordbook
  # Profile carries what upstream's meson `profile` option decides at configure
  # time, ported from meson.build:40-50 and data/meson.build:88-95.
  #
  # Upstream builds two separate applications out of one source tree: with
  # `-Dprofile=development` the application id becomes
  # `dev.mufeed.Wordbook.Devel`, the search provider moves to
  # `/dev/mufeed/Wordbook/Devel/SearchProvider`, the Devel icon is installed
  # under that id and the window wears the `devel` CSS class — so a developer's
  # copy can sit in the launcher beside a stable one without either shadowing
  # the other.
  #
  # Meson resolves the profile when the build tree is configured; this port has
  # no configure step, so the profile is read from the environment instead.
  # flake.nix's `packages.devel` sets `WORDBOOK_PROFILE=development` in the
  # launcher's wrapper, which is the same decision made in the same place: at
  # packaging time, once per installed copy.
  module Profile
    BASE_ID = "dev.mufeed.Wordbook"
    DEVEL_SUFFIX = "Devel"
    ENV_NAME = "WORDBOOK_PROFILE"
    DEVELOPMENT = "development"

    def self.name = ENV.fetch(ENV_NAME, "")

    def self.development? = name == DEVELOPMENT

    def self.app_id = development? ? "#{BASE_ID}.#{DEVEL_SUFFIX}" : BASE_ID

    # Upstream's `object_path` in data/meson.build:88-95. The bus name is the
    # application id plus `.SearchProvider`, as the .ini template says.
    def self.object_path
      development? ? "/dev/mufeed/Wordbook/Devel/SearchProvider" : "/dev/mufeed/Wordbook/SearchProvider"
    end

    def self.bus_name = "#{app_id}.SearchProvider"
  end
end
