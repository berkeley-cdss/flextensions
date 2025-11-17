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
#  course_to_lms_id       :bigint           not null
#  external_assignment_id :string
#
# Foreign Keys
#
#  fk_rails_...  (course_to_lms_id => course_to_lmss.id)
#
class Assignment < ApplicationRecord
  belongs_to :course_to_lms
  has_many :requests, dependent: :destroy

  validates :name, presence: true
  validates :external_assignment_id, presence: true

  validate :enabled_requires_date_present

  delegate :lms_id, to: :course_to_lms
  delegate :lms, to: :course_to_lms

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

  def external_url
    base_lms_url = course_to_lms.lms.lms_base_url if course_to_lms
    case lms_id
    when Lms.CANVAS.id
      "#{base_lms_url}/courses/#{external_course_id}/assignments/#{external_assignment_id}"
    when Lms.GRADESCOPE.id
      "#{base_lms_url}/courses/#{external_course_id}/assignments/#{external_assignment_id}"
    end
  end
end
