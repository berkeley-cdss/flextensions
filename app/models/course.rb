# == Schema Information
#
# Table name: courses
#
#  id                 :bigint           not null, primary key
#  course_code        :string
#  course_name        :string
#  demo_course        :boolean          default(FALSE), not null
#  readonly_api_token :string
#  semester           :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  canvas_id          :string
#
# Indexes
#
#  index_courses_on_canvas_id           (canvas_id) UNIQUE
#  index_courses_on_readonly_api_token  (readonly_api_token) UNIQUE
#
class Course < ApplicationRecord
  has_secure_token :readonly_api_token

  after_create :regenerate_readonly_api_token_if_blank
  # Every course has exactly one course_settings record (unique index on course_id).
  after_create :create_default_course_settings

  # Associations
  # Declared before course_to_lmss so a destroy removes assignments first,
  # satisfying their FK on course_to_lms_id.
  has_many :assignments, dependent: :destroy
  has_many :course_to_lmss, dependent: :destroy
  has_many :lmss, through: :course_to_lmss
  has_many :enrollments, dependent: :destroy
  has_one :form_setting, dependent: :destroy
  has_one :course_settings, dependent: :destroy
  has_many :requests, dependent: :destroy

  has_many :users, through: :enrollments

  validates :course_name, presence: true

  # Scopes
  scope :by_semester, ->(semester) { where(semester: semester) }

  # Always load the LMS integrations
  default_scope { includes(:course_to_lmss) }

  # Semester ordering: most-recent-first.
  # Within the same year: Fall > Summer > Spring > Winter (furthest out to most recent).
  SEMESTER_SEASON_ORDER = { 'Fall' => 3, 'Summer' => 2, 'Spring' => 1, 'Winter' => 0 }.freeze

  # Returns a numeric sort key for a semester string (e.g. "Spring 2026").
  # Higher values = more recent. Suitable for descending sort.
  def self.semester_sort_key(semester)
    return [ -1, -1 ] if semester.blank?

    parts = semester.split
    season = parts[0]
    year = parts[1].to_i
    [ year, SEMESTER_SEASON_ORDER.fetch(season, -1) ]
  end

  # Sorts an array of semester strings most-recent-first.
  def self.sort_semesters(semesters)
    semesters.sort_by { |s| semester_sort_key(s) }.reverse
  end

  # Month a term starts in maps to its Berkeley season.
  # Spring starts in January, Summer in late May, Fall in late August.
  SEASON_BY_START_MONTH = {
    1 => 'Spring', 2 => 'Spring', 3 => 'Spring', 4 => 'Spring',
    5 => 'Summer', 6 => 'Summer', 7 => 'Summer',
    8 => 'Fall', 9 => 'Fall', 10 => 'Fall', 11 => 'Fall', 12 => 'Fall'
  }.freeze

  # Derives a "Season Year" semester string for a Canvas course.
  # Prefers the term's name, but bCourses leaves it blank on some terms
  # (e.g. Summer 2026), so we fall back to deriving the season from the first
  # available date: the term start, then the course's own created_at (some
  # courses have neither a named term nor a term start date).
  # Returns nil when no name or parseable date is available.
  def self.semester_from_term(term, created_at = nil)
    name = term.is_a?(Hash) ? term['name'].presence : nil
    return name if name

    term_start = term.is_a?(Hash) ? term['start_at'].presence : nil
    semester_from_date(term_start || created_at)
  end

  # Builds a "Season Year" string from a date-like string, or nil if it is
  # blank or unparseable.
  def self.semester_from_date(date_string)
    return nil if date_string.blank?

    date = Date.parse(date_string.to_s)
    season = SEASON_BY_START_MONTH[date.month]
    season && "#{season} #{date.year}"
  rescue ArgumentError, TypeError
    nil
  end

  # Note: This is too close to the association, course_to_lmss
  def course_to_lms(lms_id = 1)
    CourseToLms.find_by(course_id: id, lms_id: lms_id)
  end

  def all_linked_lmss
    CourseToLms.where(course_id: id)
  end

  def has_canvas_linked?
    course_to_lms(1).present?
  end

  # Whether students can see this course and submit extension requests.
  def requests_enabled?
    course_settings.enable_extensions?
  end

  def enabled_assignments
    assignments.where(enabled: true)
  end

  # TODO: Replace this with staff_role?(user) or student_role?(user)
  # Or is user.staff_role?(course) or user.student_role?(course) better?
  def user_role(user)
    roles = Enrollment.where(user_id: user.id, course_id: id).pluck(:role)
    return 'instructor' if roles.intersect?(Enrollment.staff_roles)
    return 'student' if roles.include?(Enrollment::STUDENT_ROLE)

    nil
  end

  def enrolled?(user)
    enrollments.where(user_id: user.id).any?
  end

  def course_admin?(user)
    enrollments.where(user_id: user.id).any?(&:course_admin?)
  end

  def staff_user?(user)
    enrollments.where(user_id: user.id).any?(&:staff?)
  end

  def student_user?(user)
    enrollments.where(user_id: user.id).any?(&:student?)
  end

  # TODO: This doesn't make sense actually.
  # A course can be linked to many LMSs.
  # def lms_facade
  #   course_to_lms = CourseToLms.find_by(id: course_to_lms_id)
  #   Lms.facade_class(course_to_lms.lms_id)
  # end

  def canvas_id
    CourseToLms.find_by(course_id: id, lms_id: CANVAS_LMS_ID)&.external_course_id
  end

  def gradescope_id
    CourseToLms.find_by(course_id: id, lms_id: GRADESCOPE_LMS_ID)&.external_course_id
  end

  # TODO: Add specs for these 3 simple methods
  def students
    enrollments.where(role: Enrollment::STUDENT_ROLE).map(&:user)
  end

  def instructors
    enrollments.where(role: Enrollment::TEACHER_ROLE).map(&:user)
  end

  def staff_users
    enrollments.where(role: Enrollment.staff_roles).map(&:user)
  end

  # Staff users with Canvas credentials on file, most recently refreshed
  # first -- Canvas revokes refresh tokens that go unused for months, so the
  # staff member who logged in most recently is the most likely to still
  # work. Credentials on file can still fail to refresh or belong to someone
  # who has since left the Canvas course, so callers should be prepared to
  # fall back to the next user in this list.
  def staff_users_for_auto_approval
    staff_users.select { |user| user.canvas_credentials.present? }
               .sort_by { |user| user.canvas_credentials.updated_at }
               .reverse
  end

  def staff_user_for_auto_approval
    staff_users_for_auto_approval.first
  end

  # Fetch courses from Canvas API
  # TODO: This belongs elsewhere.
  def self.fetch_courses(token)
    all_courses = CanvasFacade.new(token).get_all_courses

    if all_courses.is_a?(Array)
      all_courses
    else
      Rails.logger.error 'Failed to fetch courses'
      []
    end
  end

  # Create or find a course and its associated CourseToLms and assignments
  def self.create_or_update_from_canvas(course_data, token, user)
    course = find_or_create_course(course_data, token)
    course_to_lms = find_or_create_course_to_lms(course, course_data)

    # Creating a 1 to 1 form_settings record to course since the instructor is only meant to update form_settings
    unless course.form_setting
      form_setting = course.build_form_setting(
        documentation_desc: <<~DESC,
          Please provide links to any additional details if relevant.
        DESC
        documentation_disp: 'hidden',
        custom_q1_disp: 'hidden',
        custom_q2_disp: 'hidden'
      )
      form_setting.save!
    end

    # TODO: Consider disabling these if performance becomes an issue
    course.sync_assignments(user)
    course.sync_all_enrollments_from_canvas(user.id)
    course
  end

  # Find or create the course
  def self.find_or_create_course(course_data, token)
    canvas_facade = CanvasFacade.new(token)
    response = canvas_facade.get_course(course_data['id'])

    if response.nil? || !response.success?
      Rails.logger.error "Failed to fetch course: #{response.status} - #{response.body}"
      # TODO: Raise error to user?
      return nil
    end

    course = find_or_initialize_by(canvas_id: course_data['id'])
    response_data = JSON.parse(response.body)
    course.course_name = response_data['name']
    course.course_code = response_data['course_code']
    # Semester is sourced from the Canvas term name (e.g. "Spring 2026"), or
    # derived from a date when bCourses leaves the name blank.
    course.semester = semester_from_term(response_data['term'], response_data['created_at'])
    course.save!
    course
  end

  # Find or create the CourseToLms record
  def self.find_or_create_course_to_lms(course, course_data, lms_id = 1)
    CourseToLms.find_or_initialize_by(course_id: course.id, lms_id: lms_id).tap do |course_to_lms|
      course_to_lms.external_course_id = course_data['id']
      course_to_lms.save!
    end
  end

  # NOTE: this must be the plural course_to_lmss
  def sync_assignments(sync_user)
    lms_links = self.course_to_lmss
    return unless lms_links.any?

    lms_links.each do |course_to_lms|
      SyncAllCourseAssignmentsJob.perform_now(course_to_lms.id, sync_user.id)
    end
  end

  # Fetch users for a course and create/find their User and Enrollment records
  # TODO: This may need to become a background job
  def sync_users_from_canvas(user, roles = [ 'student' ])
    SyncUsersFromCanvasJob.perform_now(id, user, roles)
  end

  def sync_all_enrollments_from_canvas(user)
    sync_users_from_canvas(user, Enrollment.roles)
  end

  def regenerate_readonly_api_token_if_blank
    regenerate_readonly_api_token if readonly_api_token.blank?
  end

  # Course settings are created with the column defaults; the guard only
  # matters when settings were built in memory before the course was saved.
  def create_default_course_settings
    create_course_settings! unless course_settings
  end
end
