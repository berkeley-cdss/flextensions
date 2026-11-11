# frozen_string_literal: true

# End-to-end check of what happens to extensions when an assignment's deadline
# moves past them, against a real Canvas sandbox and using the actual application
# code (Request#approve, SyncAllCourseAssignmentsJob, StaleExtensionRemover,
# CanvasFacade). See https://github.com/berkeley-cdss/flextensions/issues/620.
#
# THIS SCRIPT TEMPORARILY MOVES THE DEADLINE OF THE TEST ASSIGNMENTS. It only
# touches the three "Flextensions Test" assignments and the five test students
# below, and it refuses to run against a production Canvas.
#
# For each assignment type (regular assignment, classic quiz, graded discussion)
# it gives the students extensions, moves the deadline 10 days later, and checks:
#   REPRO     — before a sync, Canvas still gives a student their old date, even
#               though the class deadline is now later. This is the bug in #620.
#   SOLO      — after a sync, an override with one student is deleted, and Canvas
#               gives that student the class deadline.
#   SHARED    — two students on a shared override both come off it, and neither
#               is put back when the other is removed.
#   BYSTANDER — a third student on that override stays on it with the same dates,
#               because the date doesn't match a request Flextensions approved.
#   LATER     — an extension still later than the new deadline is left in place.
# Finally:
#   TOTALS    — the sync reports the number removed and skipped for the course page.
#   RESYNC    — syncing again changes nothing in Canvas.
#
# Usage (never hardcode the token):
#   CANVAS_TOKEN=<token> CANVAS_URL=https://ucberkeleysandbox.instructure.com \
#     bin/rails runner utils/canvas_sandbox/test_moved_deadline.rb
#
# Options via ENV:
#   CANVAS_COURSE_ID  sandbox course to test against (default 146)
#   SETTLE_SECONDS    how long to wait for Canvas to recalculate due dates (default 15)
#
# Rerunnable: it restores the deadlines and removes its overrides when it finishes,
# even after a failure. If it is killed partway through, run it again to clear the
# overrides, and run setup_test_course.rb to reset the deadlines.

abort 'Run in development, not production.' unless Rails.env.development?

TOKEN = ENV.fetch('CANVAS_TOKEN') { abort 'Set CANVAS_TOKEN.' }
CANVAS_COURSE_ID = ENV.fetch('CANVAS_COURSE_ID', '146')
SETTLE_SECONDS = ENV.fetch('SETTLE_SECONDS', '15').to_i

# Moving a deadline would affect real students, so only allow non-production hosts.
CANVAS_HOST = URI.parse(CanvasFacade::CANVAS_URL.to_s).host.to_s
unless CANVAS_HOST.match?(/sandbox|\.test\.|\.beta\.|\Alocalhost\z|\A127\.0\.0\.1\z/)
  abort "Refusing to move deadlines on #{CANVAS_HOST.inspect}: use a sandbox, test, or beta Canvas."
end

TEST_ASSIGNMENT_NAMES = [
  'Flextensions Test Assignment (regular)',
  'Flextensions Test Quiz (classic)',
  'Flextensions Test Discussion (graded)'
].freeze

# Sandbox students (course 146 roster).
STUDENTS = {
  solo: { canvas_uid: '237', name: 'Paul Gregory', email: 'paul.gregory86@example.com' },
  shared_a: { canvas_uid: '238', name: 'Kent Hansen', email: 'kent.hansen98@example.com' },
  shared_b: { canvas_uid: '239', name: 'Becky Hayes', email: 'becky.hayes43@example.com' },
  bystander: { canvas_uid: '240', name: 'Sherri Johnson', email: 'sherri.johnson53@example.com' },
  later: { canvas_uid: '241', name: 'Chad Carter', email: 'chad.carter67@example.com' }
}.freeze

# Only a local record to hold CANVAS_TOKEN. Canvas sees whoever owns the token, who
# must be able to edit the test course.
STAFF = { canvas_uid: 'moved-deadline-test-staff', name: 'Sandbox Staff', email: 'moved-deadline-test-staff@example.com' }.freeze

DEADLINE_MOVE = 10.days
# How far past the original deadline each extension ends.
EXTENSION_DAYS = { solo: 1, shared_a: 2, shared_b: 2, bystander: 3, later: 20 }.freeze

# For the two calls CanvasFacade doesn't offer. JSON is handled by hand because
# Faraday's JSON middleware can't call the JSON.parse in json 3.x.
CONN = Faraday.new(url: "#{CanvasFacade::CANVAS_URL}/api/v1",
                   headers: { 'Authorization' => "Bearer #{TOKEN}", 'Content-Type' => 'application/json' })

@results = []
@cleanup_failed = false

def record(scenario, assignment, ok, detail)
  @results << { scenario: scenario, ok: ok }
  puts format('%-9s %-40s %s %s', scenario, assignment, ok ? 'PASS' : 'FAIL', detail)
end

def facade
  @facade ||= CanvasFacade.new(TOKEN)
end

def find_or_create_user(attrs)
  user = User.find_or_initialize_by(canvas_uid: attrs[:canvas_uid])
  user.update!(name: attrs[:name], email: attrs[:email])
  user
end

def canvas_overrides(assignment)
  overrides = facade.get_all_assignment_overrides(CANVAS_COURSE_ID, assignment.external_assignment_id)
  abort "Could not read the overrides for #{assignment.name}." unless overrides.is_a?(Array)

  overrides
end

def override_for(assignment, student)
  canvas_overrides(assignment).find { |o| o['student_ids']&.map(&:to_s)&.include?(student.canvas_uid) }
end

def same_date?(first, second)
  first.present? && second.present? && (first - second).abs < StaleExtensionRemover::SAME_DATE_TOLERANCE
end

# The date Canvas actually applies to this student, after any overrides.
def effective_due_date(assignment, student)
  response = CONN.get("courses/#{CANVAS_COURSE_ID}/assignments/#{assignment.external_assignment_id}" \
                      "/submissions/#{student.canvas_uid}")
  return nil unless response.success?

  Time.zone.parse(JSON.parse(response.body)['cached_due_date'].to_s)
end

# Canvas recalculates cached due dates in the background, so allow it some time.
def wait_for_effective_due_date(assignment, student, expected)
  actual = nil
  (SETTLE_SECONDS / 3 + 1).times do |attempt|
    sleep 3 unless attempt.zero?
    actual = effective_due_date(assignment, student)
    break if same_date?(actual, expected)
  end
  actual
end

def set_canvas_dates(assignment, due_at, lock_at)
  response = CONN.put("courses/#{CANVAS_COURSE_ID}/assignments/#{assignment.external_assignment_id}",
                      { assignment: { due_at: due_at&.iso8601, lock_at: lock_at&.iso8601 } }.to_json)
  raise "Could not update the dates of #{assignment.name} (HTTP #{response.status})" unless response.success?
end

def remove_test_overrides(assignments, students)
  assignments.each do |assignment|
    students.each_value do |student|
      facade.remove_extension(CANVAS_COURSE_ID, student.canvas_uid.to_i, assignment.external_assignment_id)
    end
  end
end

# Lets the rest of the cleanup run if one step fails, as a failed step could
# otherwise leave a test assignment with its deadline moved.
def clean_up(description)
  yield
rescue StandardError => e
  @cleanup_failed = true
  puts "CLEANUP FAILED: #{description}: #{e.message}"
end

def approve_extension(course, assignment, student, days, staff)
  Request.where(user: student, assignment: assignment).delete_all
  request = course.requests.create!(assignment: assignment, user: student, reason: 'Sandbox moved-deadline test',
                                    requested_due_date: assignment.due_date + days.days)
  return request if request.approve(CanvasFacade.from_user(staff), staff)

  raise "Could not approve an extension for #{student.name}: #{request.errors.full_messages.to_sentence}"
end

# The bystander's date in Canvas comes from the shared override, but their approved
# request says something else, as if staff had changed their date in Canvas by hand.
def add_bystander(course, assignment, students)
  bystander = students[:bystander]
  Request.where(user: bystander, assignment: assignment).delete_all
  course.requests.create!(assignment: assignment, user: bystander, reason: 'Sandbox moved-deadline test',
                          status: 'approved', requested_due_date: assignment.due_date + EXTENSION_DAYS[:bystander].days)

  shared = override_for(assignment, students[:shared_a])
  response = facade.update_assignment_override(
    CANVAS_COURSE_ID, assignment.external_assignment_id, shared['id'],
    shared['student_ids'] + [ bystander.canvas_uid.to_i ],
    shared['title'], shared['due_at'], shared['unlock_at'], shared['lock_at']
  )
  raise "Could not add #{bystander.name} to the shared override (HTTP #{response.status})" unless response.success?
end

def sync_results(course_to_lms, staff)
  SyncAllCourseAssignmentsJob.perform_now(course_to_lms.id, staff.id)
  course_to_lms.reload.recent_assignment_sync['stale_extensions']
end

# ---------------------------------------------------------------------------
# Local seed mirroring the sandbox course
# ---------------------------------------------------------------------------
lms = Lms.find_or_initialize_by(id: CANVAS_LMS_ID)
lms.update!(lms_name: 'Canvas', lms_base_url: CanvasFacade::CANVAS_URL, use_auth_token: true)
staff = find_or_create_user(STAFF)
staff.lms_credentials.find_or_initialize_by(lms: Lms.CANVAS_LMS)
     .update!(token: TOKEN, refresh_token: 'none', expire_time: 1.year.from_now)
students = STUDENTS.transform_values { |attrs| find_or_create_user(attrs) }

course = Course.find_or_initialize_by(canvas_id: CANVAS_COURSE_ID)
course.update!(course_name: 'Flextensions Test Course (sandbox)', course_code: 'FLEXTEST')
course_to_lms = CourseToLms.find_or_create_by!(course: course, lms_id: CANVAS_LMS_ID) do |ctl|
  ctl.external_course_id = CANVAS_COURSE_ID
end
CourseSettings.find_or_initialize_by(course: course)
              .update!(enable_extensions: true, auto_approve_days: 0, enable_emails: false)
Enrollment.find_or_create_by!(user: staff, course: course, role: 'teacher')
students.each_value { |student| Enrollment.find_or_create_by!(user: student, course: course, role: 'student') }

canvas_assignments = facade.get_all_assignments(CANVAS_COURSE_ID).select { |a| TEST_ASSIGNMENT_NAMES.include?(a.name) }
unless canvas_assignments.size == TEST_ASSIGNMENT_NAMES.size
  abort "Expected #{TEST_ASSIGNMENT_NAMES.size} test assignments in Canvas, found #{canvas_assignments.size}. " \
        'Run setup_test_course.rb first.'
end

assignments = canvas_assignments.map do |canvas_assignment|
  local = Assignment.find_or_initialize_by(course_to_lms: course_to_lms, external_assignment_id: canvas_assignment.id.to_s)
  local.update!(name: canvas_assignment.name, due_date: canvas_assignment.due_date,
                late_due_date: canvas_assignment.late_due_date, enabled: true)
  local
end
original_dates = assignments.index_with { |assignment| [ assignment.due_date, assignment.late_due_date ] }

puts "Testing against #{CanvasFacade::CANVAS_URL}/courses/#{CANVAS_COURSE_ID}"
puts

begin
  remove_test_overrides(assignments, students)

  # -------------------------------------------------------------------------
  # Give the students extensions, then move the class deadline past them
  # -------------------------------------------------------------------------
  assignments.each do |assignment|
    %i[solo shared_a shared_b later].each do |key|
      approve_extension(course, assignment, students[key], EXTENSION_DAYS[key], staff)
    end
    add_bystander(course, assignment, students)
  end

  assignments.each do |assignment|
    due_date, late_due_date = original_dates[assignment]
    set_canvas_dates(assignment, due_date + DEADLINE_MOVE, late_due_date && (late_due_date + DEADLINE_MOVE))
  end

  # -------------------------------------------------------------------------
  # Before syncing: Canvas should still be using the old date (the bug)
  # -------------------------------------------------------------------------
  puts "Moved the deadlines. Waiting #{SETTLE_SECONDS}s for Canvas to recalculate due dates..."
  sleep SETTLE_SECONDS
  assignments.each do |assignment|
    old_date = original_dates[assignment].first + EXTENSION_DAYS[:solo].days
    actual = effective_due_date(assignment, students[:solo])
    record('REPRO', assignment.name, same_date?(actual, old_date),
           "Canvas applies #{actual&.iso8601 || 'no date'} (old extension #{old_date.iso8601}, " \
           "class #{(original_dates[assignment].first + DEADLINE_MOVE).iso8601})")
  end

  # -------------------------------------------------------------------------
  # Sync, then check what happened to each student
  # -------------------------------------------------------------------------
  totals = sync_results(course_to_lms, staff)
  expected_totals = { 'removed' => 3 * assignments.size, 'skipped' => assignments.size, 'failed' => 0 }
  record('TOTALS', 'all', totals == expected_totals, "got #{totals}, expected #{expected_totals}")

  assignments.each do |assignment|
    class_date = original_dates[assignment].first + DEADLINE_MOVE

    effective = wait_for_effective_due_date(assignment, students[:solo], class_date)
    gone = override_for(assignment, students[:solo]).nil?
    record('SOLO', assignment.name, gone && same_date?(effective, class_date),
           "override #{gone ? 'removed' : 'STILL THERE'}, Canvas applies #{effective&.iso8601 || 'no date'} " \
           "(class #{class_date.iso8601})")

    still_on = %i[shared_a shared_b].select { |key| override_for(assignment, students[key]) }
    record('SHARED', assignment.name, still_on.empty?,
           still_on.empty? ? 'both students are off the shared override' : "still on an override: #{still_on}")

    bystander_override = override_for(assignment, students[:bystander])
    shared_date = original_dates[assignment].first + EXTENSION_DAYS[:shared_a].days
    kept = bystander_override && same_date?(Time.zone.parse(bystander_override['due_at']), shared_date)
    record('BYSTANDER', assignment.name, !!kept,
           kept ? "still on override #{bystander_override['id']}, due #{bystander_override['due_at']}" : 'lost their override')

    later_override = override_for(assignment, students[:later])
    later_date = original_dates[assignment].first + EXTENSION_DAYS[:later].days
    kept = later_override && same_date?(Time.zone.parse(later_override['due_at']), later_date)
    record('LATER', assignment.name, !!kept,
           kept ? "still has override #{later_override['id']}, due #{later_override['due_at']}" : 'lost their extension')
  end

  # -------------------------------------------------------------------------
  # Syncing again should change nothing
  # -------------------------------------------------------------------------
  before_resync = assignments.map { |assignment| canvas_overrides(assignment) }
  totals = sync_results(course_to_lms, staff)
  unchanged = before_resync == assignments.map { |assignment| canvas_overrides(assignment) }
  expected_totals = { 'removed' => 0, 'skipped' => assignments.size, 'failed' => 0 }
  record('RESYNC', 'all', unchanged && totals == expected_totals,
         "overrides #{unchanged ? 'unchanged' : 'CHANGED'}, got #{totals}, expected #{expected_totals}")
ensure
  # -------------------------------------------------------------------------
  # Cleanup
  # -------------------------------------------------------------------------
  puts "\nRestoring the deadlines and removing this run's overrides..."
  assignments.each do |assignment|
    clean_up("restoring the dates of #{assignment.name}") do
      set_canvas_dates(assignment, *original_dates[assignment])
      assignment.update!(due_date: original_dates[assignment].first, late_due_date: original_dates[assignment].last)
    end
    students.each_value do |student|
      clean_up("removing the override for #{student.name} on #{assignment.name}") do
        facade.remove_extension(CANVAS_COURSE_ID, student.canvas_uid.to_i, assignment.external_assignment_id)
      end
    end
  end
  clean_up('deleting the local test requests') do
    Request.where(assignment: assignments, user: students.values).delete_all
  end
end

failures = @results.count { |result| !result[:ok] }
puts format("\n%d checks, %d failed", @results.size, failures)
puts 'Cleanup was incomplete: check the test assignments in Canvas.' if @cleanup_failed
exit(failures.zero? && !@cleanup_failed ? 0 : 1)
