# app/models/assignment.rb
# == Schema Information
#
# Table name: assignments
#
#  id                     :bigint           not null, primary key
#  due_date               :datetime
#  enabled                :boolean          default(FALSE)
#  late_due_date          :datetime
#  name                   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  course_id              :bigint           not null
#  course_to_lms_id       :bigint           not null
#  external_assignment_id :string
#
# Indexes
#
#  index_assignments_on_course_id  (course_id)
#
# Foreign Keys
#
#  fk_rails_...  (course_id => courses.id)
#  fk_rails_...  (course_to_lms_id => course_to_lmss.id)
#
class Assignment < ApplicationRecord
  belongs_to :course_to_lms
  belongs_to :course
  has_many :requests, dependent: :destroy

  # course_id is a denormalized copy of course_to_lms.course_id that lets us look
  # up a course's assignments without joining through course_to_lmss. Populate it
  # automatically so every creation path (sync job, API, seeds) stays in sync.
  before_validation :assign_course_from_lms

  validates :name, presence: true
  validates :external_assignment_id, presence: true

  validate :enabled_requires_date_present

  delegate :lms_id, to: :course_to_lms

  # Returns enabled assignments for a specific course
  scope :enabled_for_course, ->(course_to_lms_id) { where(course_to_lms_id: course_to_lms_id, enabled: true) }

  # Check if there's a pending request for this assignment by a specific user
  def has_pending_request_for_user?(user, course)
    requests.exists?(user: user, course: course, status: 'pending')
  end

  def enabled_requires_date_present
    errors.add(:due_date, 'must be present if assignment is enabled') if enabled && due_date.blank?
  end

  def lms_facade
    Lms.facade_class(lms_id)
  end

  # TODO: Arguably we should get the base URL from the course
  def external_url
    base_lms_url = course_to_lms.lms.lms_base_url if course_to_lms
    case lms_id
    when CANVAS_LMS_ID
      "#{base_lms_url}/courses/#{external_course_id}/assignments/#{external_assignment_id}"
    when GRADESCOPE_LMS_ID
      "#{base_lms_url}/courses/#{external_course_id}/assignments/#{external_assignment_id}"
    end
  end

  private

  # Mirror the course from the LMS link so course_id is always populated.
  def assign_course_from_lms
    self.course ||= course_to_lms&.course
  end
end
