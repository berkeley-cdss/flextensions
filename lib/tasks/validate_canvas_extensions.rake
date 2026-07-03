# Rerunnable Canvas extension validation.
#
# Exercises the REAL production code path (CanvasFacade#provision_extension) so
# you can confirm that extensions are correctly written to Canvas for every
# assignment type -- plain assignments, graded discussions, classic quizzes, and
# New Quizzes -- rather than only unit-testing it with mocks.
#
# It never persists the token: pass it in the environment for a single run.
#
# Usage (from the repo root):
#
#   CANVAS_URL=https://ucberkeleysandbox.instructure.com \
#   CANVAS_TOKEN=xxxxx \
#   COURSE_ID=<canvas_course_id> \
#   STUDENT_ID=<canvas_user_id> \
#   ASSIGNMENT_IDS=<id1,id2,...> \
#   DUE_AT=2026-08-01T23:59:00Z \
#   bundle exec rails canvas:validate_extensions
#
# ASSIGNMENT_IDS accepts the *assignment* id shown by the assignments endpoint.
# Graded discussions and New Quizzes expose an assignment id there and work
# directly. Classic quizzes expose a quiz_id too; include the assignment id and
# watch for a failure, which would confirm the classic-quiz gap (the app has no
# write scope for /quizzes/:quiz_id/assignment_overrides).
namespace :canvas do
  desc 'Provision a test extension for each ASSIGNMENT_IDS via the real CanvasFacade'
  task validate_extensions: :environment do
    token = ENV.fetch('CANVAS_TOKEN')
    course_id = ENV.fetch('COURSE_ID')
    student_id = ENV.fetch('STUDENT_ID')
    assignment_ids = ENV.fetch('ASSIGNMENT_IDS').split(',').map(&:strip).reject(&:empty?)
    due_at = ENV.fetch('DUE_AT', 1.week.from_now.iso8601)
    late_due_at = ENV['LATE_DUE_AT'].presence

    facade = CanvasFacade.new(token)

    puts "Canvas:   #{CanvasFacade::CANVAS_URL}"
    puts "Course:   #{course_id}"
    puts "Student:  #{student_id}"
    puts "New due:  #{due_at}#{" (late: #{late_due_at})" if late_due_at}"
    puts '-' * 60

    assignment_ids.each do |assignment_id|
      override = facade.provision_extension(course_id, student_id, assignment_id, due_at, late_due_at)
      puts "OK   assignment #{assignment_id}: override ##{override.id}"
    rescue StandardError => e
      puts "FAIL assignment #{assignment_id}: #{e.class} - #{e.message}"
    end
  end
end
