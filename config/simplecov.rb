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
  # Give each test step a distinct command name (set via COVERAGE_COMMAND in CI)
  # so their resultsets accumulate in coverage/.resultset.json and SimpleCov
  # merges them into one report, instead of a later run clobbering an earlier
  # one that shares the default guessed name. Falls back to SimpleCov's guess
  # (e.g. "RSpec" / "Cucumber Features") when the variable is unset.
  command_name ENV['COVERAGE_COMMAND'] unless ENV['COVERAGE_COMMAND'].to_s.empty?

  formatter SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::JSONFormatter
    ]
  )
end
