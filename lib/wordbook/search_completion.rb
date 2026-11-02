# frozen_string_literal: true

require "adwaita"

module Wordbook
  # SearchCompletion is the completion popover under the search entry: the
  # words the wordlist offers for what has been typed, navigable with the arrow
  # keys, completed with Tab and searched with Return.
  #
  # A port of upstream's wordbook/search_completion.py. It is only in use while
  # live search is off — with live search on, the definitions themselves are
  # the feedback, which is why the window disables this.
  #
  # The popover is parented to the window and pointed at the entry on every
  # update, which is what upstream does
  # (`wordbook/search_completion.py:45,122-135`). The first version of this
  # file parented it to the entry and synced only its width, and claimed that
  # put it in the same place — a claim about where a widget lands made by
  # someone who had never seen it land. Where it actually lands is still
  # unobserved: this port has never been rendered (FINDINGS.md, defect 5), so
  # the geometry below is upstream's arithmetic carried across rather than a
  # measured match.
  #
  class SearchCompletion
    ENTRY_CLASS = "completion-entry"
    ENTRY_ACTIVE_CLASS = "completion-active"
    MAX_ITEMS = 10

    def initialize(parent:, entry:, item_provider:, activate:)
      @parent = parent
      @entry = entry
      @item_provider = item_provider
      @activate = activate
      @enabled = false
      @items = []
    end

    def build
      popover.tap do |pop|
        pop.child = scroller
        pop.set_parent(@parent)
        pop.signal_connect("closed") { entry_active(false) }

        scroller.tap do |window|
          window.child = listbox

          listbox.signal_connect("row-activated") { |_list, row| activate_index(row.index) }
        end

        @entry.add_css_class(ENTRY_CLASS)
        @entry.add_controller(key_controller)
        @entry.add_controller(focus_controller)
        @parent.add_controller(click_controller)

        key_controller.signal_connect("key-pressed") { |_controller, keyval, _code, _state| key_pressed(keyval) }

        focus_controller.tap do |controller|
          controller.signal_connect("enter") { update(@entry.text) }
          controller.signal_connect("leave") { GLib::Idle.add { hide_if_focus_lost } }
        end

        click_controller.signal_connect("pressed") { |_gesture, _n_press, x, y| parent_pressed(x, y) }
      end
    end

    def enabled=(enabled)
      @enabled = enabled
      if enabled
        update(@entry.text)
      else
        clear
      end
    end

    # Rebuilds the list for what is currently typed, and pops the popover up
    # or down accordingly. Nothing is shown while the entry is unfocused, so a
    # programmatic set_text never opens it.
    def update(text)
      if showable?(text)
        show_items(@item_provider.call(text, MAX_ITEMS))
      else
        hide
      end
    end

    def clear
      @items = []
      remove_rows
      hide
    end

    def hide
      listbox.unselect_all
      entry_active(false)
      if popover.visible?
        popover.popdown
      end
    end

    # True when the key was consumed, which is what stops Return from also
    # triggering the window's default widget.
    def key_pressed(keyval)
      if popover.visible?
        handle_key(keyval)
      else
        false
      end
    end

    def entry_has_focus?
      @entry.root.then do |root|
        contains?(@entry, root && root.focus)
      end
    end

    # Memoized widgets

    def popover
      @popover ||= Gtk::Popover.new.tap do |pop|
        pop.autohide = false
        pop.has_arrow = false
        pop.position = :bottom
        pop.focusable = false
        pop.add_css_class("completion-popover")
      end
    end

    def scroller
      @scroller ||= Gtk::ScrolledWindow.new.tap do |window|
        window.hscrollbar_policy = :never
        window.propagate_natural_height = true
        window.focusable = false
        window.has_frame = false
      end
    end

    def listbox
      @listbox ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :single
        list.activate_on_single_click = true
        list.focusable = false
      end
    end

    # CAPTURE phase: the entry would otherwise swallow Tab and the arrow keys
    # before the completion ever saw them.
    def key_controller
      @key_controller ||= Gtk::EventControllerKey.new.tap do |controller|
        controller.propagation_phase = :capture
      end
    end

    def focus_controller = @focus_controller ||= Gtk::EventControllerFocus.new

    def click_controller
      @click_controller ||= Gtk::GestureClick.new.tap do |controller|
        controller.propagation_phase = :capture
      end
    end

    private

      def showable?(text) = @enabled && !text.to_s.strip.empty? && entry_has_focus?

      def show_items(items)
        @items = Array(items)
        remove_rows
        if @items.empty?
          hide
        else
          popup_with(@items)
        end
      end

      def popup_with(items)
        items.each { |item| listbox.append(row_for(item)) }
        if sync_geometry
          present_popover
        else
          hide
        end
      end

      def present_popover
        entry_active(true)
        popover.popup
        popover.present
        @entry.grab_focus_without_selecting
      end

      # Upstream's _sync_geometry. The popover belongs to the window, so it is
      # pointed at a one-pixel-tall rectangle along the entry's bottom edge,
      # with the offset zeroed so GTK does not shift it again. A
      # compute_bounds that fails means the entry is not currently in the
      # window's coordinate space, and upstream hides the popover rather than
      # leaving it pointed at the last place the entry was.
      def sync_geometry
        entry_bounds.then do |bounds|
          if bounds
            point_at(bounds)
          else
            false
          end
        end
      end

      # compute_bounds returns the rectangle, or a [success, rectangle] pair
      # depending on how the binding unpacks its out parameter; both shapes
      # mean the same thing.
      def entry_bounds
        @entry.compute_bounds(@parent).then do |result|
          if result.is_a?(Array)
            successful_bounds(result)
          else
            result
          end
        end
      end

      def successful_bounds(result)
        if result.first
          result.last
        end
      end

      def point_at(bounds)
        [bounds.width.round, @entry.width, 1].max.then do |width|
          popover.set_offset(0, 0)
          popover.pointing_to = Gdk::Rectangle.new(
            bounds.x.round,
            (bounds.y + bounds.height).round - 1,
            width,
            1,
          )
          scroller.set_size_request(width, -1)
          true
        end
      end

      def remove_rows
        while listbox.first_child
          listbox.remove(listbox.first_child)
        end
      end

      def handle_key(keyval)
        case keyval
        when Gdk::Keyval::KEY_Down then move_selection(1)
        when Gdk::Keyval::KEY_Up then move_selection(-1)
        when Gdk::Keyval::KEY_Tab then complete_entry
        when Gdk::Keyval::KEY_Return, Gdk::Keyval::KEY_KP_Enter then activate_index(selected_index)
        when Gdk::Keyval::KEY_Escape then hide_and_consume
        else false
        end
      end

      def hide_and_consume
        hide
        true
      end

      # Tab fills the entry with the highlighted word — or the first one, when
      # nothing is highlighted yet — and leaves the search to be triggered.
      def complete_entry
        (selected_index || first_index).then do |index|
          if index
            apply_entry_text(@items[index])
            hide_and_consume
          else
            false
          end
        end
      end

      def first_index
        unless @items.empty?
          0
        end
      end

      def move_selection(step)
        if @items.empty?
          false
        else
          select_row(next_index(step))
        end
      end

      def next_index(step)
        selected_index.then do |index|
          if index
            [0, [index + step, @items.length - 1].min].max
          else
            wrap_index(step)
          end
        end
      end

      def wrap_index(step)
        if step.positive?
          0
        else
          @items.length - 1
        end
      end

      def select_row(index)
        listbox.get_row_at_index(index).then do |row|
          if row
            listbox.select_row(row)
            true
          else
            false
          end
        end
      end

      def selected_index
        listbox.selected_row.then do |row|
          if row && row.index.between?(0, @items.length - 1)
            row.index
          end
        end
      end

      def activate_index(index)
        if index && index.between?(0, @items.length - 1)
          activate_item(@items[index])
        else
          false
        end
      end

      def activate_item(item)
        clear
        @activate.call(item)
        true
      end

      # The leading whitespace the user typed is preserved, so completing
      # " wor" gives " word" rather than jumping the cursor to the front.
      def apply_entry_text(completion_text)
        @entry.text.then do |current|
          "#{current[0, current.length - current.lstrip.length]}#{completion_text}".then do |updated|
            @entry.text = updated
            @entry.position = updated.length
          end
        end
      end

      # A click anywhere in the window: inside the entry reopens the popover,
      # inside the popover is left alone, anywhere else dismisses it.
      def parent_pressed(x, y)
        @parent.pick(x, y, :default).then do |clicked|
          if clicked.nil?
            hide
          else
            dispatch_click(clicked)
          end
        end
      end

      def dispatch_click(clicked)
        if popover.visible?
          dismiss_unless_ours(clicked)
        else
          if contains?(@entry, clicked)
            GLib::Idle.add { show_if_possible }
          end
        end
      end

      def dismiss_unless_ours(clicked)
        unless contains?(@entry, clicked) || contains?(popover, clicked)
          hide
        end
      end

      def hide_if_focus_lost
        unless entry_has_focus?
          hide
        end
        false
      end

      def show_if_possible
        update(@entry.text)
        false
      end

      def entry_active(active)
        if active
          @entry.add_css_class(ENTRY_ACTIVE_CLASS)
        else
          @entry.remove_css_class(ENTRY_ACTIVE_CLASS)
        end
      end

      def contains?(ancestor, widget) = widget == ancestor || (!widget.nil? && widget.ancestor?(ancestor))

      def row_for(item)
        Gtk::ListBoxRow.new.tap do |row|
          row.activatable = true
          row.selectable = true
          row.focusable = false
          row.child = row_label(item)
        end
      end

      def row_label(item)
        Gtk::Label.new(item).tap do |label|
          label.xalign = 0
          label.ellipsize = :end
          label.margin_top = 3
          label.margin_bottom = 3
          label.margin_start = 10
          label.margin_end = 10
        end
      end
  end
end
