{
  description = "Wordbook — a Ruby GTK4 port";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Shared libraries every ruby-gnome extension links against.
        gtkStack = with pkgs; [
          glib
          gobject-introspection
          cairo
          pango
          gdk-pixbuf
          graphene
          atk
          gtk4
          libadwaita
          harfbuzz
          librsvg
        ]
        # The Ruby `pkg-config` gem resolves `Requires.private` transitively and
        # hard-fails if any .pc in the chain is missing, so gtk4's whole private
        # closure has to be on PKG_CONFIG_PATH, not just its public deps.
        ++ (with pkgs; [
          fontconfig
          freetype
          libepoxy
          libpng
          libxkbcommon
          pcre2
          util-linux
          wayland
          zlib
          fribidi
          libdatrie
          libthai
          libselinux
          libsepol
          expat
          brotli
          bzip2
          graphite2
          icu
          libffi
          libxml2
          lerc
          libdeflate
          xz
          zstd
        ])
        # Un-prefixed names: the `xorg.*` package set is deprecated.
        ++ (with pkgs; [
          libx11
          libxau
          libxcursor
          libxdmcp
          libxext
          libxfixes
          libxi
          libxinerama
          libxrandr
          libxrender
          libxcb
          xorgproto
        ]);

        # ruby-gnome gems build C extensions with extconf.rb + the pkg-config
        # gem; nixpkgs only ships gemConfig entries for the GTK3-era subset, so
        # the GTK4 gems get their build inputs declared here.
        rubyGnomeGem = _attrs: {
          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = gtkStack;
        };

        gemConfig = pkgs.defaultGemConfig // {
          gdk4 = rubyGnomeGem;
          gsk4 = rubyGnomeGem;
          gtk4 = rubyGnomeGem;
          graphene1 = rubyGnomeGem;
          adwaita = rubyGnomeGem;
          rsvg2 = rubyGnomeGem;
        };

        # `makeSearchPath` would take each package's *first* output, and glib's
        # first output is `bin`, which carries no typelibs — hence the explicit
        # `.out`. at-spi2-core is here for the Atk typelib.
        typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0"
          (map (drv: drv.out or drv) (gtkStack ++ [ pkgs.at-spi2-core ]));

        # nix/ and not the repo root: the root Gemfile is kettle-jem's
        # development bundle — rubocop, rspec, yard, the kettle-dev stack — and
        # must not end up in a packaged app's runtime closure. nix/Gemfile holds
        # the gemspec's runtime dependencies only.
        gems = pkgs.bundlerEnv {
          name = "Wordbook-gems";
          ruby = pkgs.ruby_3_4;
          inherit gemConfig;
          gemdir = ./nix;
          groups = [ "default" ];
        };

        # The same gemdir with the `test` group included: rspec belongs in the
        # devShell and not in the packaged app's runtime closure, and
        # bundlerEnv's `groups` is the only thing that keeps those apart.
        devGems = pkgs.bundlerEnv {
          name = "Wordbook-dev-gems";
          ruby = pkgs.ruby_3_4;
          inherit gemConfig;
          gemdir = ./nix;
          groups = [ "default" "test" ];
        };

        # Every script the gemspec installs into exe/ gets a wrapper. Reading
        # the directory keeps this flake generic: no name to keep in step by
        # hand. The first one is the app; the rest are services like the GNOME
        # Shell search provider, which the shell starts through its D-Bus
        # .service file and which therefore has to exist in $out/bin.
        launchers = builtins.attrNames (builtins.readDir ./exe);
        launcher = builtins.head launchers;

        # Optional directories: a port that has not grown translations or data
        # assets yet simply has none.
        optionalDirs = builtins.filter (d: builtins.pathExists (./. + "/${d}")) [
          "data"
          "po"
        ];
        # Upstream builds two applications out of one tree: meson.build:43-49
        # turns `-Dprofile=development` into the application id
        # `dev.mufeed.Wordbook.Devel`, and data/meson.build:88-95 moves the
        # search provider's object path with it. `mkWordbook` is that option.
        # Everything the id appears in — the desktop entry, the metainfo, the
        # icon, the GSettings schema, the search provider's .ini and .service —
        # is substituted from these three values, so `packages.default` and
        # `packages.devel` can be installed side by side.
        mkWordbook = { development ? false }:
          let
            appId = if development then "dev.mufeed.Wordbook.Devel" else "dev.mufeed.Wordbook";
            objectPath =
              if development
              then "/dev/mufeed/Wordbook/Devel/SearchProvider"
              else "/dev/mufeed/Wordbook/SearchProvider";
            iconSource =
              if development
              then "data/icons/dev.mufeed.Wordbook.Devel.svg"
              else "data/icons/dev.mufeed.Wordbook.svg";
            # What lib/wordbook/profile.rb reads. Empty is the stable profile,
            # which is also what a bare `ruby exe/wordbook` gets.
            profileName = if development then "development" else "";
            # glib's setup hook relocates share/glib-2.0/schemas into
            # share/gsettings-schemas/<pname>-<version> during fixup, so the
            # wrapper has to name the profile's own directory.
            schemaDir = if development then "Wordbook-Devel-0.1.0" else "Wordbook-0.1.0";
          in
          pkgs.stdenv.mkDerivation {
          pname = if development then "Wordbook-Devel" else "Wordbook";
          version = "0.1.0";
          src = ./.;

          # Deliberately no wrapGAppsHook4: glib's setup hook relocates
          # share/glib-2.0/schemas during fixup, after wrapGAppsHook4 has
          # computed its wrapper arguments, so a schema would end up somewhere
          # the wrapper never looks. The wrapper below is built by hand and
          # points at both the pre- and post-move paths.
          nativeBuildInputs = [ pkgs.makeWrapper ];
          buildInputs = [ gems ] ++ gtkStack;

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/Wordbook
            cp -r lib $out/share/Wordbook/
            for d in ${pkgs.lib.escapeShellArgs optionalDirs}; do
              cp -r "$d" $out/share/Wordbook/
            done
            # exe/ sits next to lib/ so each launcher's `require "wordbook"`
            # resolves against the copied tree.
            for e in ${pkgs.lib.escapeShellArgs launchers}; do
              install -Dm755 "exe/$e" "$out/share/Wordbook/exe/$e"
            done

            # The desktop entry, the metainfo, the icons and the search
            # provider files, in the XDG locations that give the app a
            # launcher, an icon, an entry in Software and a search provider the
            # shell can find. msgfmt merges po/ into the first two, which is
            # what meson's i18n.merge_file does for upstream; the @app-id@,
            # @APP_ID@ and @object_path@ substitutions are what meson's
            # configure_file does.
            if [ -d data ]; then
              mkdir -p gen
              install -Dm644 ${iconSource} \
                $out/share/icons/hicolor/scalable/apps/${appId}.svg
              install -Dm644 data/icons/dev.mufeed.Wordbook-symbolic.svg \
                $out/share/icons/hicolor/symbolic/apps/dev.mufeed.Wordbook-symbolic.svg

              mkdir -p $out/share/applications $out/share/metainfo \
                $out/share/dbus-1/services $out/share/gnome-shell/search-providers

              sed "s|@app-id@|${appId}|g" data/dev.mufeed.Wordbook.desktop.in \
                > gen/${appId}.desktop.in
              ${pkgs.gettext}/bin/msgfmt --desktop \
                --template=gen/${appId}.desktop.in -d po \
                -o $out/share/applications/${appId}.desktop

              sed "s|@app-id@|${appId}|g" data/dev.mufeed.Wordbook.metainfo.xml.in \
                > gen/${appId}.metainfo.xml.in
              ${pkgs.gettext}/bin/msgfmt --xml \
                --template=gen/${appId}.metainfo.xml.in -d po \
                -o $out/share/metainfo/${appId}.metainfo.xml

              sed -e "s|@APP_ID@|${appId}|g" -e "s|@object_path@|${objectPath}|g" \
                data/dev.mufeed.Wordbook.SearchProvider.ini \
                > $out/share/gnome-shell/search-providers/${appId}.SearchProvider.ini

              sed -e "s|@APP_ID@|${appId}|g" -e "s|@bindir@|$out/bin|g" \
                data/dev.mufeed.Wordbook.SearchProvider.service.in \
                > $out/share/dbus-1/services/${appId}.SearchProvider.service
            fi

            # The compiled catalogues: upstream's fifteen languages, where
            # Wordbook::Translations looks for them.
            if [ -d po ]; then
              for lang in $(cat po/LINGUAS); do
                install -Dm644 /dev/null \
                  $out/share/Wordbook/locale/$lang/LC_MESSAGES/wordbook.mo
                ${pkgs.gettext}/bin/msgfmt -o \
                  $out/share/Wordbook/locale/$lang/LC_MESSAGES/wordbook.mo \
                  po/$lang.po
              done
            fi

            # The GSettings schema, substituted and compiled the way
            # data/meson.build:62-71 installs upstream's.
            if [ -d data/schemas ]; then
              mkdir -p $out/share/glib-2.0/schemas
              for schema in data/schemas/*.gschema.xml.in; do
                sed "s|@app-id@|${appId}|g" "$schema" \
                  > $out/share/glib-2.0/schemas/${appId}.gschema.xml
              done
              ${pkgs.glib.dev}/bin/glib-compile-schemas --strict \
                $out/share/glib-2.0/schemas
            fi

            # -rbundler/setup puts the bundled gems on the load path, and
            # GI_TYPELIB_PATH keeps GObject-Introspection from re-registering
            # types the cairo gem's C extension has already registered.
            for e in ${pkgs.lib.escapeShellArgs launchers}; do
              makeWrapper ${gems.wrappedRuby}/bin/ruby $out/bin/"$e" \
                --add-flags "-rbundler/setup" \
                --add-flags "-I$out/share/Wordbook/lib" \
                --add-flags "$out/share/Wordbook/exe/$e" \
                --set GI_TYPELIB_PATH "${typelibPath}" \
                --set WORDBOOK_PROFILE "${profileName}" \
                --set BUNDLE_WITHOUT "test" \
                --prefix XDG_DATA_DIRS : "$out/share" \
                --prefix XDG_DATA_DIRS : "$out/share/gsettings-schemas/${schemaDir}" \
                --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}" \
                --prefix XDG_DATA_DIRS : "${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}" \
                --prefix XDG_DATA_DIRS : "${pkgs.adwaita-icon-theme}/share"
            done

            runHook postInstall
          '';

          meta = {
            description =
              if development
              then "A Ruby GTK4 / Libadwaita port of Wordbook (development profile)"
              else "A Ruby GTK4 / Libadwaita port of Wordbook";
            mainProgram = launcher;
            platforms = pkgs.lib.platforms.linux;
          };
        };
      in
      {
        packages.default = mkWordbook { };

        # Upstream's `-Dprofile=development`: a second installable copy under
        # dev.mufeed.Wordbook.Devel, with its own icon, desktop entry,
        # metainfo, schema and search provider object path, and with the
        # `devel` CSS class on its window.
        packages.devel = mkWordbook { development = true; };

        apps.default = utils.lib.mkApp { drv = self.packages.${system}.default; };
        apps.devel = utils.lib.mkApp { drv = self.packages.${system}.devel; };

        # `nix flake check` runs these. The first one is here because the
        # packaged app shipped for a whole round with sqlite3 missing from
        # nix/gemset.nix: the gem was in the devShell, so every check passed
        # and the only installable artifact raised
        # `LoadError: cannot load such file -- sqlite3` on the user's first
        # search. A check that reads a database through the built wrapper is
        # the thing that would have caught it.
        checks = {
          packaged-database-read = pkgs.runCommand "Wordbook-packaged-database-read"
            { nativeBuildInputs = [ pkgs.sqlite ]; }
            ''
              set -euo pipefail
              # A WordNet-shaped database, read the way lib/wordbook/base.rb
              # reads the real one.
              sqlite3 wn.db \
                "CREATE TABLE lexicons (id TEXT, version TEXT, specifier TEXT);" \
                "INSERT INTO lexicons VALUES ('oewn', '2025', 'oewn:2025+');"
              # BUNDLE_WITHOUT is what the installed launcher's wrapper sets;
              # the check runs the same ruby the same way.
              export BUNDLE_WITHOUT=test
              ${gems.wrappedRuby}/bin/ruby -rbundler/setup \
                -I${self.packages.${system}.default}/share/Wordbook/lib \
                -e 'require "sqlite3"
                    row = nil
                    SQLite3::Database.new("wn.db") { |db|
                      row = db.execute("SELECT specifier FROM lexicons").flatten.first
                    }
                    raise "unexpected specifier: #{row.inspect}" unless row == "oewn:2025+"
                    print "packaged ruby read the lexicon specifier: #{row}\n"'
              touch $out
            '';

          # The three tests upstream declares in data/meson.build:36, :58 and
          # :76, run over the files this flake actually installs rather than
          # over the templates.
          data-files = pkgs.runCommand "Wordbook-data-files"
            {
              nativeBuildInputs = [
                pkgs.desktop-file-utils
                pkgs.appstream
                pkgs.glib.dev
              ];
            }
            ''
              set -euo pipefail
              share=${self.packages.${system}.default}/share
              desktop-file-validate $share/applications/dev.mufeed.Wordbook.desktop
              appstreamcli validate --no-net \
                $share/metainfo/dev.mufeed.Wordbook.metainfo.xml
              # glib's setup hook relocates share/glib-2.0/schemas during
              # fixup, so the installed schema is under gsettings-schemas/.
              mkdir -p schemas
              cp $share/gsettings-schemas/Wordbook-0.1.0/glib-2.0/schemas/*.gschema.xml schemas/
              glib-compile-schemas --strict --dry-run schemas
              touch $out
            '';
        };

        devShells.default = pkgs.mkShell {
          name = "Wordbook-devshell";

          packages = [
            devGems
            devGems.wrappedRuby
            pkgs.bundler
            pkgs.bundix
            pkgs.pkg-config
            pkgs.glib.dev
            pkgs.gettext
            # rxgettext, the extractor `rake pot` drives. GNU xgettext claims
            # to support Ruby but only shells out to this, so without it
            # `xgettext --language=Ruby` fails.
            pkgs.rubyPackages_3_4.gettext
            # The spec runner. The suite is plain RSpec, so this is enough.
            pkgs.rubyPackages_3_4.rspec
            # sqlite3 is the app's own runtime dependency
            # (lib/wordbook/base.rb): without it every search lands on
            # "Database not found" and the content page can never be driven.
            # nix/gemset.nix now carries it too, so the packaged app has it as
            # well; this entry is what `ruby exe/wordbook` in the shell uses.
            pkgs.rubyPackages_3_4.sqlite3
            # The three validators upstream's data/meson.build declares as
            # tests, so `rake data:validate` can be run by hand here and not
            # only through `nix flake check`.
            pkgs.desktop-file-utils
            pkgs.appstream
            # espeak-ng, the program lib/wordbook/espeak.rb shells out to.
            # Without it the pronunciation fallback and the "read it aloud"
            # button are code no run has ever entered.
            pkgs.espeak-ng
            # zstd, the program lib/wordbook/database_manager.rb unpacks the
            # bundled WordNet archive with (FINDINGS.md, defect 4).
            pkgs.zstd
            # This machine may have no display server at all, so the shell
            # carries one it can start itself: `xvfb-run ruby exe/<app>` both
            # launches the app and is how test/drive_*.rb is run.
            pkgs.xvfb-run
            # dbus-run-session: test/drive_wordbook.rb gives each probe process
            # a session bus of its own, so a second copy of the app does not
            # become a remote instance of the one the driver is running.
            pkgs.dbus
            pkgs.gsettings-desktop-schemas
            pkgs.adwaita-icon-theme
          ] ++ gtkStack;

          # Icons, GSettings schemas and the GTK portal all resolve through
          # XDG_DATA_DIRS; without these the window opens with blank icons.
          shellHook = ''
            export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}:${pkgs.adwaita-icon-theme}/share:$XDG_DATA_DIRS"
            export GI_TYPELIB_PATH="${typelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
            export RUBYLIB="$PWD/lib''${RUBYLIB:+:$RUBYLIB}"
            # data/schemas holds the @app-id@ template; GSettings needs a
            # substituted, compiled copy, so the shell builds one.
            if [ -d data/schemas ]; then
              mkdir -p tmp/schemas
              for schema in data/schemas/*.gschema.xml.in; do
                sed "s|@app-id@|dev.mufeed.Wordbook|g" "$schema" \
                  > "tmp/schemas/dev.mufeed.Wordbook.gschema.xml"
              done
              ${pkgs.glib.dev}/bin/glib-compile-schemas --strict tmp/schemas
              export GSETTINGS_SCHEMA_DIR="$PWD/tmp/schemas''${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"
            fi
            # The message catalogues the app reads at runtime. They are built
            # here as well as committed so that a clone whose po/ has moved on
            # is not quietly English.
            for lang in $(cat po/LINGUAS); do
              install -Dm644 /dev/null "locale/$lang/LC_MESSAGES/wordbook.mo"
              ${pkgs.gettext}/bin/msgfmt -o "locale/$lang/LC_MESSAGES/wordbook.mo" "po/$lang.po"
            done
            unset BUNDLE_GEMFILE BUNDLE_FROZEN
            echo "Wordbook devshell — ruby $(ruby -e 'print RUBY_VERSION')"
            echo "run the app:     xvfb-run ruby exe/wordbook"
            echo "run the devel:   WORDBOOK_PROFILE=development xvfb-run ruby exe/wordbook"
            echo "drive the app:   xvfb-run ruby test/drive_*.rb"
            echo "run the specs:   ruby -e 'require \"rspec/core\"; exit RSpec::Core::Runner.run([\"--format\", \"progress\", \"--require\", \"spec_helper\", \"spec\"])'"
            echo "build locale/:   rake locale        (po/*.po -> locale/<lang>/LC_MESSAGES/wordbook.mo)"
            echo "validate data:   rake data:validate (upstream's three meson tests)"
          '';
        };
      });
}
