# frozen_string_literal: true

# Shared SimpleCov configuration used by both test suites so their coverage
# setup never drifts:
#   * RSpec    -> required from spec/spec_helper.rb
#   * Cucumber -> required from features/support/env.rb
#
# This must be required before any application code loads so SimpleCov can hook
# into Coverage. As of SimpleCov 1.0 the JSON formatter is bundled with the gem
# (the standalone simplecov_json_formatter gem is no longer needed), and calling
# SimpleCov.start more than once in a process is a no-op rather than an error.
require 'simplecov'

SimpleCov.start 'rails' do
  formatter SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::JSONFormatter
    ]
  )
end
