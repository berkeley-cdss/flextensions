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
  belongs_to :course
  belongs_to :course_to_lms
  has_many :requests, dependent: :destroy
  has_many :extensions, dependent: :destroy

  # course_id is denormalized from course_to_lms so course-scoped queries
  # don't need a join; default it so callers only have to set course_to_lms.
  before_validation :set_course_from_course_to_lms

  validates :name, presence: true
  validates :external_assignment_id, presence: true

  validate :enabled_requires_date_present

  delegate :lms_id, to: :course_to_lms

  # Check if there's a pending request for this assignment by a specific user
  def has_pending_request_for_user?(user, course)
    requests.exists?(user: user, course: course, status: 'pending')
  end

  def set_course_from_course_to_lms
    self.course ||= course_to_lms&.course
  end

  def enabled_requires_date_present
    errors.add(:due_date, 'must be present if assignment is enabled') if enabled && due_date.blank?
  end

  def lms_facade
    Lms.facade_class(lms_id)
  end

  # TODO: Arguably we should get the base URL from the course
  # The per-LMS URL structure lives on each facade, so this just supplies the
  # base URL and external ids and lets the facade assemble the link.
  def external_url
    return unless course_to_lms

    lms_facade.assignment_url(
      course_to_lms.lms.lms_base_url,
      course_to_lms.external_course_id,
      external_assignment_id
    )
  end
end
