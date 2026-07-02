# == Schema Information
#
# Table name: enrollments
#
#  id                      :bigint           not null, primary key
#  allow_extended_requests :boolean          default(FALSE), not null
#  removed                 :boolean          default(FALSE), not null
#  role                    :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  course_id               :bigint
#  user_id                 :bigint
#
# Indexes
#
#  index_enrollments_on_course_id  (course_id)
#  index_enrollments_on_user_id    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (course_id => courses.id)
#  fk_rails_...  (user_id => users.id)
#
class Enrollment < ApplicationRecord
  STUDENT_ROLE = 'student'.freeze
  TEACHER_ROLE = 'teacher'.freeze
  TA_ROLE = 'ta'.freeze
  LEAD_TA_ROLE = 'leadta'.freeze
  STAFF_ROLES = [ TEACHER_ROLE, TA_ROLE, LEAD_TA_ROLE ].freeze
  COURSE_ADMIN_ROLES = [ TEACHER_ROLE, LEAD_TA_ROLE ].freeze
  ROLE_LABELS = {
    LEAD_TA_ROLE => 'Lead TA'
  }.freeze
  # Role ranking from lowest to highest, used to pick a single role when a
  # user holds more than one in the same course.
  ROLE_PRIORITY = [ STUDENT_ROLE, TA_ROLE, LEAD_TA_ROLE, TEACHER_ROLE ].freeze

  # Associations
  belongs_to :user
  belongs_to :course

  # Validations
  # NOTE: Validations are skipped when a User is created by SyncUsersFromCanvasJob
  # You should update that job if these validations become complex.
  # In the meantime, we can trust that the data coming from Canvas is valid.
  validates :role, presence: true


  def staff?
    Enrollment.staff_roles.include?(role)
  end

  def course_admin?
    Enrollment.course_admin_roles.include?(role)
  end

  def student?
    role == STUDENT_ROLE
  end

  def display_role
    Enrollment.display_role(role)
  end

  # Rank of this enrollment's role; higher wins. Unknown roles rank lowest.
  def role_priority
    ROLE_PRIORITY.index(role) || -1
  end

  # Collapses a set of enrollments (typically one user's enrollments across
  # courses) to at most one per course, keeping the highest-ranked role. This
  # prevents a user who holds multiple roles in the same course from appearing
  # more than once in a course list.
  def self.keep_highest_role
    all.group_by(&:course_id).map do |_course_id, enrollments|
      enrollments.max_by(&:role_priority)
    end
  end

  def self.roles
    [ STUDENT_ROLE ] + Enrollment.staff_roles
  end

  def self.staff_roles
    STAFF_ROLES
  end

  def self.course_admin_roles
    COURSE_ADMIN_ROLES
  end

  def self.normalize_role(role)
    role.to_s.downcase.gsub(/[^a-z]/, '')
  end

  def self.role_from_canvas_enrollment(enrollment)
    return nil unless enrollment

    normalized_role = normalize_role(enrollment['role'] || enrollment[:role])
    return LEAD_TA_ROLE if normalized_role == LEAD_TA_ROLE

    normalized_type = normalize_role(enrollment['type'] || enrollment[:type])
    roles.include?(normalized_type) ? normalized_type : nil
  end

  def self.staff_enrollment?(enrollment)
    staff_roles.include?(role_from_canvas_enrollment(enrollment))
  end

  def self.display_role(role)
    ROLE_LABELS.fetch(role.to_s, role.to_s.capitalize)
  end
end
