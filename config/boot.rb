ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Surface Ruby-level deprecation warnings (off by default since Ruby 3.0) in
# every environment so deprecated language/stdlib usage is visible everywhere:
# development, CI, and production logs alike.
Warning[:deprecated] = true

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
