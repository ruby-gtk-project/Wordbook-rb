# frozen_string_literal: true

require "adwaita"

require_relative "translations"

module Wordbook
  # ErrorDialog is the one-button alert the window shows for the two errors
  # that are not a page of their own: a search that cleaned away to nothing,
  # and a random word asked for before the wordlist finished loading.
  #
  # Ported from _new_error in upstream's wordbook/window.py.
  #
  # Not a subclass: Adwaita::AlertDialog takes its heading and body
  # positionally, so the dialog is built inside and presented through this
  # small wrapper. Upstream calls `choose`, which hands the chosen response to
  # a coroutine; there is only one response here, so `present` is the same
  # thing without the await.
  #
  class ErrorDialog
    include Translations

    DISMISS = "dismiss"

    def initialize(primary_text, secondary_text)
      @primary_text = primary_text
      @secondary_text = secondary_text
    end

    def present(parent) = dialog.tap { |alert| alert.present(parent) }

    def dialog
      @dialog ||= Adwaita::AlertDialog.new(@primary_text, @secondary_text).tap do |alert|
        alert.add_response(DISMISS, _("Dismiss"))
        alert.default_response = DISMISS
        alert.close_response = DISMISS
      end
    end
  end
end
