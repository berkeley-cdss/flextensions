class UserToCoursePolicy < ApplicationPolicy
  # record is a UserToCourse (enrollment)

  # Only course admins (teacher/leadta) can toggle extended circumstances
  def toggle_allow_extended_requests?
    course_admin? || site_admin?
  end

  private

  def enrollment
    @enrollment ||= UserToCourse.find_by(user: user, course_id: record.course_id)
  end

  def course_admin?
    enrollment&.course_admin? || false
  end
end
