# == Schema Information
#
# Table name: course_to_lmss
#
#  id                     :bigint           not null, primary key
#  recent_assignment_sync :jsonb
#  recent_roster_sync     :jsonb
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  course_id              :bigint
#  external_course_id     :string
#  lms_id                 :bigint
#
# Indexes
#
#  index_course_to_lmss_on_course_id_and_lms_id           (course_id,lms_id) UNIQUE
#  index_course_to_lmss_on_lms_id_and_external_course_id  (lms_id,external_course_id)
#
# Foreign Keys
#
#  fk_rails_...  (course_id => courses.id)
#  fk_rails_...  (lms_id => lmss.id)
#
class CourseToLms < ApplicationRecord
  # Associations
  belongs_to :course
  belongs_to :lms

  # One link per course and LMS, and one Flextensions course per external
  # course: otherwise assignment sync would import the same LMS assignments
  # into two courses and approvals would provision extensions twice. Both are
  # also enforced by indexes; the validations give callers a clean error.
  validates :lms_id, uniqueness: { scope: :course_id }
  validates :external_course_id, uniqueness: { scope: :lms_id }, allow_blank: true

  # Fetch assignments from Canvas API
  def get_all_canvas_assignments(user)
    CanvasFacade.from_user(user).get_all_assignments(external_course_id)
  rescue StandardError => e
    Rails.logger.error "Failed to fetch Canvas assignments: #{e.message}"
    Rails.error.report(e, handled: true,
                       context: { component: 'canvas_assignments', course_to_lms_id: id, external_course_id: external_course_id })
    []
  end

  def fetch_gradescope_assignments
    return [] unless course.course_settings.enable_gradescope?

    GradescopeFacade.from_user.get_all_assignments(external_course_id)
  rescue StandardError => e
    Rails.logger.error "Failed to fetch Gradescope assignments: #{e.message}"
    Rails.error.report(e, handled: true,
                       context: { component: 'gradescope_assignments', course_to_lms_id: id, external_course_id: external_course_id })
    []
  end
end
