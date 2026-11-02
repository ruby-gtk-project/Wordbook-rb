# frozen_string_literal: true

require "gtk4"

module Wordbook
  # HistoryObject is one entry in the search history, ported from the class of
  # the same name in upstream's wordbook/window.py: a term and whether it is
  # favourited.
  #
  # It is a GLib::Object because the sidebar's Gio::ListStore can only hold
  # GObjects, and `type_register` is what gives the Ruby class a GType for the
  # store to be created with.
  #
  class HistoryObject < GLib::Object
    type_register

    attr_accessor :term
    attr_writer :favorite

    def initialize(term, favorite: false)
      super()
      @term = term.to_s
      @favorite = favorite == true
    end

    def favorite? = @favorite
  end
end
