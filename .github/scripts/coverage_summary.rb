# frozen_string_literal: true

# Prints a Markdown coverage summary and appends it to the GitHub Actions job
# summary ($GITHUB_STEP_SUMMARY) when that variable is set.
#
# It reads the merged SimpleCov report under coverage/. When a job runs several
# test steps that each write to coverage/ under a distinct SimpleCov command
# name (see config/simplecov.rb + COVERAGE_COMMAND), SimpleCov merges their
# resultsets, so the figure reported here reflects the union of those steps
# rather than only the last one to run.
#
# Usage: ruby .github/scripts/coverage_summary.rb "RSpec coverage"

require 'json'

def read_json(path)
  JSON.parse(File.read(path, encoding: 'UTF-8'))
rescue StandardError
  nil
end

title = ARGV[0] || 'Coverage'
rows = []

# Preferred source: the JSON formatter's coverage.json, which carries a `total`
# section with covered/total counts per criterion.
data = read_json(File.join('coverage', 'coverage.json'))
if data.is_a?(Hash) && data['total'].is_a?(Hash)
  data['total'].each do |criterion, stats|
    next unless stats.is_a?(Hash) && stats['percent']

    value = format('%.2f%%', stats['percent'])
    if stats['covered'] && stats['total']
      value += " (#{stats['covered']}/#{stats['total']})"
    end
    rows << [criterion.capitalize, value]
  end
end

# Fallback: the lightweight .last_run.json, always written by SimpleCov.
if rows.empty?
  last_run = read_json(File.join('coverage', '.last_run.json'))
  result = last_run.is_a?(Hash) ? last_run['result'] : nil
  (result || {}).each do |criterion, percent|
    rows << [criterion.capitalize, format('%.2f%%', percent)]
  end
end

output =
  if rows.empty?
    "## #{title}\n\nNo coverage report was found under `coverage/`.\n"
  else
    table = rows.map { |name, value| "| #{name} | #{value} |" }.join("\n")
    "## #{title}\n\n| Metric | Coverage |\n| --- | --- |\n#{table}\n"
  end

puts output

summary_path = ENV['GITHUB_STEP_SUMMARY']
File.write(summary_path, "#{output}\n", mode: 'a') if summary_path && !summary_path.empty?
