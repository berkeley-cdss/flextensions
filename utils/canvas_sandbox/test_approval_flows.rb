# frozen_string_literal: true

# End-to-end exercise of Flextensions' approval flows against a real Canvas
# sandbox, using the actual application code (Request#process_created_request,
# Request#approve, CanvasFacade#provision_extension).
#
# For each assignment type (regular assignment, classic quiz, graded
# discussion) it runs:
#   1. AUTO   — a request inside auto_approve_days, submitted via the same
#               entry point the controller uses; must end up approved,
#               auto_approved, and visible as an override in Canvas.
#   2. MANUAL — a request outside auto_approve_days; must stay pending, then
#               be approved with the staff user's facade and appear in Canvas.
#   3. GROUP  — a second student requesting the same extension length; must
#               join the first student's override group, not get a new one.
# Finally it reruns AUTO for a course whose first-enrolled staff member has no
# Canvas credentials (the roster-synced-TA scenario reported in production).
#
# Usage (never hardcode the token):
#   CANVAS_TOKEN=<token> CANVAS_URL=https://ucberkeleysandbox.instructure.com \
#     bin/rails runner utils/canvas_sandbox/test_approval_flows.rb
#
# Options via ENV:
#   CANVAS_COURSE_ID  sandbox course to test against (default 146)
#   KEEP_OVERRIDES=1  leave the Canvas overrides in place for inspection
#
# Rerunnable: it deletes the local test requests it created and (unless
# KEEP_OVERRIDES=1) the Canvas overrides it provisioned.

abort 'Run in development, not production.' unless Rails.env.development?

TOKEN = ENV.fetch('CANVAS_TOKEN') { abort 'Set CANVAS_TOKEN.' }
CANVAS_COURSE_ID = ENV.fetch('CANVAS_COURSE_ID', '146')

TEST_ASSIGNMENT_NAMES = [
  'Flextensions Test Assignment (regular)',
  'Flextensions Test Quiz (classic)',
  'Flextensions Test Discussion (graded)'
].freeze

# Sandbox students (course 146 roster). auto/manual/group are exercised on
# every assignment type; no_creds_staff only on the first.
STUDENTS = {
  auto: { canvas_uid: '237', name: 'Paul Gregory', email: 'paul.gregory86@example.com' },
  manual: { canvas_uid: '238', name: 'Kent Hansen', email: 'kent.hansen98@example.com' },
  group: { canvas_uid: '239', name: 'Becky Hayes', email: 'becky.hayes43@example.com' },
  no_creds: { canvas_uid: '240', name: 'Sherri Johnson', email: 'sherri.johnson53@example.com' }
}.freeze

STAFF = { canvas_uid: '136', name: 'Michael Ball', email: 'ball@berkeley.edu' }.freeze
NO_CREDS_STAFF = { canvas_uid: '999136', name: 'No Creds TA', email: 'no-creds-ta@example.com' }.freeze

@results = []
@created_override_keys = [] # [canvas_course_id, external_assignment_id]

def record(scenario, assignment, ok, detail)
  @results << { scenario: scenario, assignment: assignment, ok: ok, detail: detail }
  puts format('%-8s %-40s %s %s', scenario, assignment, ok ? 'PASS' : 'FAIL', detail)
end

def facade
  @facade ||= CanvasFacade.new(TOKEN)
end

def find_or_create_user(attrs)
  user = User.find_or_initialize_by(canvas_uid: attrs[:canvas_uid])
  user.update!(name: attrs[:name], email: attrs[:email])
  user
end

def give_canvas_credentials(user)
  cred = user.lms_credentials.find_or_initialize_by(lms_name: 'canvas')
  cred.update!(token: TOKEN, refresh_token: 'none', expire_time: 1.year.from_now)
end

def enroll(user, course, role)
  UserToCourse.find_or_create_by!(user: user, course: course, role: role)
end

def canvas_override_for(assignment, student)
  overrides = facade.get_all_assignment_overrides(CANVAS_COURSE_ID, assignment.external_assignment_id)
  return nil unless overrides.is_a?(Array)

  overrides.find { |o| o['student_ids']&.map(&:to_s)&.include?(student.canvas_uid) }
end

def build_request(course, assignment, student, days)
  # Rerunnable: drop any previous test request for this student+assignment.
  Request.where(user: student, assignment: assignment).delete_all
  course.requests.create!(
    assignment: assignment,
    user: student,
    reason: 'Sandbox approval-flow test',
    requested_due_date: assignment.due_date + days.days
  )
end

def verify_in_canvas(scenario, assignment, student, request)
  override = canvas_override_for(assignment, student)
  return record(scenario, assignment.name, false, 'no override found in Canvas') unless override

  @created_override_keys << [ assignment, student ]
  due_ok = Time.zone.parse(override['due_at']) == request.requested_due_date
  record(scenario, assignment.name, due_ok,
         "override #{override['id']} '#{override['title']}' due=#{override['due_at']}" \
         "#{due_ok ? '' : " (expected #{request.requested_due_date.iso8601})"}")
  override
end

# ---------------------------------------------------------------------------
# Local seed mirroring the sandbox course
# ---------------------------------------------------------------------------
lms = Lms.find_or_initialize_by(id: CANVAS_LMS_ID)
lms.update!(lms_name: 'Canvas', lms_base_url: CanvasFacade::CANVAS_URL, use_auth_token: true)
staff = find_or_create_user(STAFF)
give_canvas_credentials(staff)
students = STUDENTS.transform_values { |attrs| find_or_create_user(attrs) }

course = Course.find_or_initialize_by(canvas_id: CANVAS_COURSE_ID)
course.update!(course_name: 'Flextensions Test Course (sandbox)', course_code: 'FLEXTEST')
course_to_lms = CourseToLms.find_or_create_by!(course: course, lms_id: CANVAS_LMS_ID) do |ctl|
  ctl.external_course_id = CANVAS_COURSE_ID
end

settings = CourseSettings.find_or_initialize_by(course: course)
settings.update!(enable_extensions: true, auto_approve_days: 3, max_auto_approve: 0,
                 enable_emails: false, min_hours_before_deadline: 0)

# Make the credentialed staff user the course's only staff enrollment.
UserToCourse.where(course: course).delete_all
enroll(staff, course, 'teacher')
students.each_value { |s| enroll(s, course, 'student') }

# Sync the three test assignments from Canvas through the real facade.
assignments = facade.get_all_assignments(CANVAS_COURSE_ID).select { |a| TEST_ASSIGNMENT_NAMES.include?(a.name) }
abort "Expected 3 test assignments in Canvas, found #{assignments.size}. Run setup_test_course.rb first." unless assignments.size == 3

local_assignments = assignments.map do |a|
  local = Assignment.find_or_initialize_by(course_to_lms: course_to_lms, external_assignment_id: a.id.to_s)
  local.update!(name: a.name, due_date: a.due_date, late_due_date: a.late_due_date, enabled: true)
  local
end

puts "Testing against #{CanvasFacade::CANVAS_URL}/courses/#{CANVAS_COURSE_ID}"
puts

# ---------------------------------------------------------------------------
# Scenarios, per assignment type
# ---------------------------------------------------------------------------
local_assignments.each do |assignment|
  # AUTO: inside auto_approve_days, entering through the code path the
  # controller uses on create.
  request = build_request(course, assignment, students[:auto], 2)
  request.process_created_request(students[:auto])
  request.reload
  if request.status == 'approved' && request.auto_approved
    verify_in_canvas('AUTO', assignment, students[:auto], request)
  else
    record('AUTO', assignment.name, false,
           "status=#{request.status} auto_approved=#{request.auto_approved} errors=#{request.errors.full_messages}")
  end

  # MANUAL: outside auto_approve_days -> stays pending -> staff approves.
  request = build_request(course, assignment, students[:manual], 10)
  request.process_created_request(students[:manual])
  request.reload
  if request.status != 'pending'
    record('MANUAL', assignment.name, false, "expected pending after create, got #{request.status}")
  elsif request.approve(CanvasFacade.from_user(staff), staff) && request.reload.status == 'approved'
    verify_in_canvas('MANUAL', assignment, students[:manual], request)
  else
    record('MANUAL', assignment.name, false, "approve failed: #{request.errors.full_messages}")
  end

  # GROUP: same extension length as AUTO student -> should join their override.
  request = build_request(course, assignment, students[:group], 2)
  request.process_created_request(students[:group])
  request.reload
  if request.status == 'approved'
    override = canvas_override_for(assignment, students[:group])
    shared = override && override['student_ids'].map(&:to_s).include?(students[:auto].canvas_uid)
    @created_override_keys << [ assignment, students[:group] ] if override
    record('GROUP', assignment.name, !!shared,
           override ? "override #{override['id']} students=#{override['student_ids']}" : 'no override found')
  else
    record('GROUP', assignment.name, false, "status=#{request.status} errors=#{request.errors.full_messages}")
  end
end

# ---------------------------------------------------------------------------
# Production repro: first-enrolled staff member has no Canvas credentials
# (e.g. a TA synced from the Canvas roster who never logged into Flextensions).
# ---------------------------------------------------------------------------
no_creds_staff = find_or_create_user(NO_CREDS_STAFF)
no_creds_staff.lms_credentials.destroy_all
UserToCourse.where(course: course, role: UserToCourse.staff_roles).delete_all
enroll(no_creds_staff, course, 'ta')   # enrolled first -> arbitrary .first picks them
enroll(staff, course, 'teacher')

assignment = local_assignments.first
request = build_request(course, assignment, students[:no_creds], 2)
request.process_created_request(students[:no_creds])
request.reload
if request.status == 'approved'
  verify_in_canvas('NOCREDS', assignment, students[:no_creds], request)
else
  record('NOCREDS', assignment.name, false,
         "request stayed '#{request.status}' — auto-approval silently skipped " \
         'because the first staff enrollment has no Canvas credentials')
end

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
if ENV['KEEP_OVERRIDES'] == '1'
  puts "\nKEEP_OVERRIDES=1 — leaving Canvas overrides in place."
else
  puts "\nCleaning up Canvas overrides created by this run..."
  @created_override_keys.uniq.each do |assignment, student|
    override = canvas_override_for(assignment, student)
    next unless override

    remaining = override['student_ids'].map(&:to_s) - [ student.canvas_uid ]
    if remaining.empty?
      facade.delete_assignment_override(CANVAS_COURSE_ID, assignment.external_assignment_id, override['id'])
    else
      facade.update_assignment_override(CANVAS_COURSE_ID, assignment.external_assignment_id, override['id'],
                                        remaining, override['title'], override['due_at'],
                                        override['unlock_at'], override['lock_at'])
    end
  end
end

failures = @results.count { |r| !r[:ok] }
puts format("\n%d scenarios, %d failed", @results.size, failures)
exit(failures.zero? ? 0 : 1)
