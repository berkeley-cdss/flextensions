ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Surface Ruby-level deprecation warnings (off by default since Ruby 3.0) in
# every environment — server, console, rake, and Elastic Beanstalk alike — so
# deprecated language/stdlib usage is caught ahead of the next Ruby upgrade.
Warning[:deprecated] = true

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
