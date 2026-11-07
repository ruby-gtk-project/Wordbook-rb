# frozen_string_literal: true

# Drives Wordbook::ShellSearchProvider over a real D-Bus connection: a real
# session bus, a real service process that owns the bus name and registers
# the object, and `gdbus call` against the org.gnome.Shell.SearchProvider2
# interface for every method it implements.
#
# Why this file exists: spec/wordbook/shell_search_provider_spec.rb and
# test/drive_wordbook.rb both call the provider's methods
# (#initial_result_set, #result_metas, ...) as plain Ruby — useful for pinning
# behaviour, but it never exercises `register`, `handle_method_call`,
# `interface_info` (Gio::DBusNodeInfo#lookup_interface) or the hand-written
# GVariant text builders (`string_array`, `metas_variant`) against an actual
# D-Bus connection, where a wrong reply signature or a bad NODE_XML would show
# up as a real protocol error instead of a Ruby return value. This does that:
# the provider runs in its own process, exactly as `exe/wordbook-search-provider`
# does for the real shell, and every call crosses a real socket.
#
# Run it from the repository root. `require "gtk4"` initializes GTK at load
# time in these bindings (`Gtk::Loader#pre_load`) even though this script
# never opens a window, so xvfb-run is not optional here either:
#
#   nix develop --command xvfb-run -a ruby test/drive_search_provider_dbus.rb
#
# It re-execs itself once under `dbus-run-session` so it gets a private
# session bus rather than reusing whatever is ambient.

require "fileutils"
require "open3"
require "tmpdir"

INNER_MARKER = "WORDBOOK_DBUS_DRIVE_INNER"

unless ENV[INNER_MARKER]
  exec(
    { INNER_MARKER => "1" },
    "dbus-run-session",
    "--",
    RbConfig.ruby,
    __FILE__,
  )
end

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("wordbook-dbus-drive-config")
ENV["XDG_DATA_HOME"] = Dir.mktmpdir("wordbook-dbus-drive-data")

require "wordbook/constants"
require "wordbook/database_manager"
require_relative "wn_fixture"

Wordbook::WnFixture.write(Wordbook::DatabaseManager.extracted_db_path)

BUS_NAME = "dev.mufeed.Wordbook.SearchProvider"
OBJECT_PATH = "/dev/mufeed/Wordbook/SearchProvider"
INTERFACE = "org.gnome.Shell.SearchProvider2"

CHECKS = []

def check(description)
  CHECKS << [description, yield]
  puts "    #{CHECKS.last[1] ? "ok  " : "FAIL"} #{description}"
rescue StandardError => e
  CHECKS << [description, false]
  puts "    FAIL #{description} (#{e.class}: #{e.message})"
end

def gdbus_call(method, signature)
  Open3.capture3(
    "gdbus",
    "call",
    "--session",
    "--dest",
    BUS_NAME,
    "--object-path",
    OBJECT_PATH,
    "--method",
    "#{INTERFACE}.#{method}",
    *signature,
  )
end

def bus_name_owned?
  stdout, = Open3.capture3(
    "gdbus",
    "call",
    "--session",
    "--dest",
    "org.freedesktop.DBus",
    "--object-path",
    "/org/freedesktop/DBus",
    "--method",
    "org.freedesktop.DBus.NameHasOwner",
    BUS_NAME,
  )
  stdout.strip == "(true,)"
end

def wait_for_bus_name(timeout: 10)
  deadline = Time.now + timeout
  until bus_name_owned?
    (Time.now > deadline) ? (break false) : sleep(0.1)
  end
  true
end

puts "[1] starting the provider as its own process, as the shell does"
# `true` rather than a real "wordbook" binary — ActivateResult/LaunchSearch
# only need something Process.spawn can exec; the app binary itself is not
# under test here.
child_env = { "WORDBOOK_BIN" => `which true`.strip }
child_pid = Process.spawn(
  child_env,
  RbConfig.ruby,
  "-I",
  File.expand_path("../lib", __dir__),
  File.expand_path("../exe/wordbook-search-provider", __dir__),
  chdir: File.expand_path("..", __dir__),
)

check("the bus name is owned within 10s") { wait_for_bus_name }

puts "[2] introspecting the real object"
check("the object answers Introspect with the SearchProvider2 interface") do
  stdout, = Open3.capture3(
    "gdbus",
    "introspect",
    "--session",
    "--dest",
    BUS_NAME,
    "--object-path",
    OBJECT_PATH,
  )
  stdout.include?(INTERFACE) && stdout.include?("GetInitialResultSet")
end

puts "[3] GetInitialResultSet(['word'])"
initial_stdout = nil
check("replies with an array of result ids") do
  stdout, _stderr, status = gdbus_call("GetInitialResultSet", ["[\"word\"]"])
  initial_stdout = stdout
  status.success? && stdout.start_with?("(['")
end
result_id = initial_stdout&.match(/\['([^']+)'/)&.captures&.first

puts "[4] GetSubsearchResultSet(previous, ['word'])"
# Re-keys its own results with a fresh UUID per call, same as
# GetInitialResultSet (see the class comment) — so the id used below for
# GetResultMetas has to come from whichever call ran last, not from step 3.
check("narrows the same way GetInitialResultSet did") do
  stdout, _stderr, status = gdbus_call("GetSubsearchResultSet", ["[\"#{result_id}\"]", "[\"word\"]"])
  result_id = stdout.match(/\['([^']+)'/)&.captures&.first
  status.success? && stdout.start_with?("(['")
end

puts "[5] GetResultMetas([id])"
check("replies with one meta dict carrying id/name/description") do
  stdout, _stderr, status = gdbus_call("GetResultMetas", ["[\"#{result_id}\"]"])
  status.success? && stdout.include?("'id'") && stdout.include?("'name'")
end

puts "[6] ActivateResult(id, [], 0) — spawns `true`, not a real app"
check("returns without error over the bus") do
  _stdout, _stderr, status = gdbus_call("ActivateResult", ["\"#{result_id}\"", "[]", "0"])
  status.success?
end

puts "[7] LaunchSearch(['word'], 0)"
check("returns without error over the bus") do
  _stdout, _stderr, status = gdbus_call("LaunchSearch", ["[\"word\"]", "0"])
  status.success?
end

Process.kill("TERM", child_pid)
Process.wait(child_pid)

failed = CHECKS.reject { |_, ok| ok }
puts "#{CHECKS.length - failed.length} of #{CHECKS.length} checks passed"
puts(failed.empty? ? "DBUS DRIVE OK" : "DBUS DRIVE FAILED (#{failed.length})")
exit(failed.empty? ? 0 : 1)
