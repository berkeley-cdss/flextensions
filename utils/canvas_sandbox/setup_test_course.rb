#!/usr/bin/env ruby
# frozen_string_literal: true

# Ensures a Canvas sandbox course has one of each assignment type Flextensions
# must support: a regular assignment, a classic quiz, and a graded discussion.
# Safe to rerun: existing items (matched by name) are reused and their due
# dates pushed into the future.
#
# Usage:
#   CANVAS_TOKEN=<token> [CANVAS_URL=https://ucberkeleysandbox.instructure.com] \
#   [CANVAS_COURSE_ID=146] ruby utils/canvas_sandbox/setup_test_course.rb
#
# Prints the Canvas URLs of everything it created or found.

require 'faraday'
require 'json'
require 'time'

CANVAS_URL = ENV.fetch('CANVAS_URL', 'https://ucberkeleysandbox.instructure.com')
COURSE_ID = ENV.fetch('CANVAS_COURSE_ID', '146')
TOKEN = ENV.fetch('CANVAS_TOKEN') { abort 'Set CANVAS_TOKEN (do not hardcode tokens).' }

DUE_AT  = (Time.now.utc + (30 * 24 * 3600)).strftime('%Y-%m-%dT23:59:00Z')
LOCK_AT = (Time.now.utc + (33 * 24 * 3600)).strftime('%Y-%m-%dT23:59:00Z')

CONN = Faraday.new(url: "#{CANVAS_URL}/api/v1") do |f|
  f.request :json
  f.response :json
  f.headers['Authorization'] = "Bearer #{TOKEN}"
end

def find_assignment_by_name(name)
  assignments = CONN.get("courses/#{COURSE_ID}/assignments", { per_page: 100, search_term: name }).body
  return nil unless assignments.is_a?(Array)

  assignments.find { |a| a['name'] == name }
end

def update_assignment_dates(assignment_id)
  CONN.put("courses/#{COURSE_ID}/assignments/#{assignment_id}", {
    assignment: { due_at: DUE_AT, lock_at: LOCK_AT, published: true }
  }).body
end

def ensure_regular_assignment(name)
  existing = find_assignment_by_name(name)
  return update_assignment_dates(existing['id']) if existing

  CONN.post("courses/#{COURSE_ID}/assignments", {
    assignment: {
      name: name,
      submission_types: [ 'online_text_entry' ],
      points_possible: 10,
      due_at: DUE_AT,
      lock_at: LOCK_AT,
      published: true
    }
  }).body
end

# A classic quiz is created through the quizzes endpoint; Canvas creates a
# shadow assignment (assignment_id) which is what Flextensions syncs and
# provisions overrides against.
def ensure_classic_quiz(name)
  existing = find_assignment_by_name(name)
  return update_assignment_dates(existing['id']) if existing

  quiz = CONN.post("courses/#{COURSE_ID}/quizzes", {
    quiz: {
      title: name,
      quiz_type: 'assignment',
      due_at: DUE_AT,
      lock_at: LOCK_AT,
      published: true
    }
  }).body
  abort "Failed to create classic quiz: #{quiz}" unless quiz.is_a?(Hash) && quiz['id']

  find_assignment_by_name(name)
end

# A graded discussion is created through the discussion_topics endpoint with
# an assignment payload; Canvas again creates a shadow assignment.
def ensure_graded_discussion(name)
  existing = find_assignment_by_name(name)
  return update_assignment_dates(existing['id']) if existing

  topic = CONN.post("courses/#{COURSE_ID}/discussion_topics", {
    title: name,
    message: 'Created by Flextensions approval testing (utils/canvas_sandbox).',
    published: true,
    assignment: { points_possible: 5, due_at: DUE_AT, lock_at: LOCK_AT }
  }).body
  abort "Failed to create graded discussion: #{topic}" unless topic.is_a?(Hash) && topic['id']

  find_assignment_by_name(name)
end

course = CONN.get("courses/#{COURSE_ID}").body
abort "Cannot access course #{COURSE_ID}: #{course}" unless course.is_a?(Hash) && course['id']

puts "Course: #{course['name']} — #{CANVAS_URL}/courses/#{COURSE_ID}"
puts "Due date used: #{DUE_AT} (lock/late date #{LOCK_AT})"
puts

{
  'Flextensions Test Assignment (regular)' => method(:ensure_regular_assignment),
  'Flextensions Test Quiz (classic)' => method(:ensure_classic_quiz),
  'Flextensions Test Discussion (graded)' => method(:ensure_graded_discussion)
}.each do |name, ensure_fn|
  assignment = ensure_fn.call(name)
  if assignment.is_a?(Hash) && assignment['id']
    puts format('%-42s assignment_id=%-5s %s', name, assignment['id'],
                "#{CANVAS_URL}/courses/#{COURSE_ID}/assignments/#{assignment['id']}")
  else
    puts format('%-42s FAILED: %s', name, assignment.inspect)
  end
end

students = CONN.get("courses/#{COURSE_ID}/users", { 'enrollment_type[]' => 'student', per_page: 100 }).body
puts
puts "Students available as test roster (#{students.size}):"
students.first(8).each { |s| puts "  #{s['id']}: #{s['name']} <#{s['email']}>" }
puts '  ...' if students.size > 8
