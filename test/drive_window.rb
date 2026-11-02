# frozen_string_literal: true

require "fileutils"
require "wordbook"

module Wordbook
  # WindowDriver presents the real application on a virtual display and checks
  # the widgets GTK actually built, rather than the ones the source says it
  # builds. It exists because `ruby -c` and a successful `require` prove
  # nothing about a window: the first time this port was presented, the
  # accessible labels aborted the startup (FINDINGS.md, defect 10) and the
  # source had read as correct for a whole round.
  #
  # Run it from the dev shell:
  #
  #     nix develop --command xvfb-run -a ruby test/drive_window.rb
  #
  # It exits 0 when every check passes and 1 when any of them fails, and it
  # leaves one PNG per checkpoint in `tmp/screenshots`.
  #
  # The window lands on the database-error page unless a WordNet archive is
  # installed (FINDINGS.md, defect 7), so the checks here are the ones that do
  # not need a database: the window class, the widget tree, the breakpoint and
  # every action.
  class WindowDriver
    SHOT_DIR = "tmp/screenshots"
    SETTLE = 600
    STARTUP = 1_500
    WIDE = 900
    NARROW = 420

    def initialize
      @application = Application.new
      @failures = []
      @checks = 0
    end

    def run
      FileUtils.mkdir_p(SHOT_DIR)
      application.tap do |app|
        app.signal_connect("activate") { GLib::Timeout.add(STARTUP) { start } }
        app.run([$PROGRAM_NAME])
      end
      report
    end

    def application = @application_object ||= @application.build

    private

      # Each step returns the next one, so the driver walks the list on one
      # timeout rather than nesting a block per checkpoint.
      def start
        [
          method(:check_window),
          method(:check_tree),
          method(:check_live_search),
          method(:check_wide),
          method(:check_narrow),
          method(:check_wide_again),
          method(:check_sidebar_binding),
          method(:check_shortcuts_dialog),
          method(:shoot_shortcuts_dialog),
          method(:check_actions),
        ].then { |steps| advance(steps) }
        false
      end

      def advance(steps)
        steps.first.then do |step|
          if step
            step.call
            GLib::Timeout.add(SETTLE) { advance(steps.drop(1)) }
          else
            application.quit
          end
        end
        false
      end

      def window = @application.window

      def check_window
        check("the window is an AdwApplicationWindow") { window.window.is_a?(Adwaita::ApplicationWindow) }
        check("the window is titled Wordbook") { window.window.title == "Wordbook" }
        check("the window is on screen") { window.window.visible? }
        shoot("window")
      end

      def check_tree
        check("the content is the toast overlay") { window.window.content.equal?(window.toast_overlay) }
        check("the overlay holds the split view") { window.toast_overlay.child.equal?(window.split_view) }
        check("the split view holds the sidebar") { window.split_view.sidebar.is_a?(Gtk::Widget) }
        check("the split view holds the toolbar") { window.split_view.content.equal?(window.content_toolbar) }
        check("the spinner page is an AdwSpinner") { window.spinner_page.is_a?(Adwaita::Spinner) }
      end

      # The template's `focus-widget` and `default-widget` are set when the
      # window is built, and GTK then moves both: it gives the focus elsewhere
      # while the header is insensitive, and it clears the default widget when
      # that widget is hidden — which is what live search does to the search
      # button, upstream included. So what is checked here is live search's
      # effect, the part that is this port's own code.
      def check_live_search
        check("live search hides the search button") do
          window.search_button.visible? == !window.settings.live_search
        end
        check("the search entry sits in the title") { window.title_clamp.child.equal?(window.search_box) }
        check("the search box holds the entry") { window.search_entry.parent.equal?(window.search_box) }
      end

      def check_wide
        window.window.set_default_size(WIDE, 600)
      end

      # The breakpoint upstream declares on the template: libadwaita evaluates
      # `max-width: 550sp` against the allocation, so a resize alone collapses
      # the split view with nothing in this port watching for it.
      def check_narrow
        check("the split view is open when the window is wide") { !window.split_view.collapsed? }
        shoot("wide")
        window.window.set_default_size(NARROW, 600)
      end

      def check_wide_again
        check("the breakpoint collapses the split view") { window.split_view.collapsed? }
        shoot("narrow")
        window.window.set_default_size(WIDE, 600)
      end

      def check_sidebar_binding
        check("the breakpoint releases the split view") { !window.split_view.collapsed? }
        window.split_view.show_sidebar = false
        check("the toggle button follows show-sidebar") { !window.split_view_toggle_button.active? }
        window.split_view_toggle_button.active = true
        check("show-sidebar follows the toggle button") { window.split_view.show_sidebar? }
      end

      WINDOW_ACTIONS = %w[
        preferences
        toggle-sidebar
        toggle-menu
        toggle-favorites
        random-word
        search-selected
        paste-search
      ].freeze

      APP_ACTIONS = %w[about shortcuts].freeze

      def check_actions
        APP_ACTIONS.each do |name|
          check("app.#{name} activates") { activates { application.activate_action(name, nil) } }
        end
        WINDOW_ACTIONS.each do |name|
          check("win.#{name} activates") { activates { window.window.activate_action("win.#{name}", nil) } }
        end
      end

      # An AdwDialog is drawn inside the AdwApplicationWindow, so the window's
      # own paintable catches it. The shortcuts dialog is the one worth
      # looking at: its rows name an action and Adwaita fills in the key from
      # what the application bound.
      def check_shortcuts_dialog
        application.activate_action("shortcuts", nil)
      end

      def shoot_shortcuts_dialog
        check("a dialog is open over the window") { window.window.visible_dialog.is_a?(Adwaita::Dialog) }
        shoot("shortcuts")
        window.window.visible_dialog&.close
      end

      def activates
        yield
        true
      rescue StandardError, NotImplementedError => error
        @failures << "  raised #{error.class}: #{error.message}"
        false
      end

      def check(description)
        @checks += 1
        if yield
          $stdout.puts("ok   #{description}")
        else
          @failures << description
          $stdout.puts("FAIL #{description}")
        end
      end

      # A GskRenderNode of the window rendered through the window's own
      # renderer, saved as a PNG. Nothing here looks at the pixels; the file is
      # for a person to look at beside upstream's.
      def shoot(name)
        Gtk::Snapshot.new.tap do |snapshot|
          Gtk::WidgetPaintable.new(window.window).snapshot(
            snapshot,
            window.window.allocated_width,
            window.window.allocated_height,
          )
          save(snapshot.to_node, name)
        end
      end

      def save(node, name)
        node.then do |render_node|
          if render_node
            window.window.native.renderer.render_texture(render_node, nil)
                  .save_to_png(File.join(SHOT_DIR, "#{name}.png"))
          else
            $stdout.puts("     no render node for #{name}")
          end
        end
      end

      def report
        $stdout.puts("#{@checks - @failures.length}/#{@checks} checks passed")
        @failures.empty?
      end
  end
end

exit(Wordbook::WindowDriver.new.run ? 0 : 1)
