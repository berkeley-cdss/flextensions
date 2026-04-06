class AssignmentPolicy < ApplicationPolicy
  # record is an Assignment

  # Only course admins (teacher/leadta) can toggle assignment enabled status
  def toggle_enabled?
    course_admin? || site_admin?
  end

  private

  def course
    record.course_to_lms.course
  end

  def enrollment
    @enrollment ||= UserToCourse.find_by(user: user, course_id: course.id)
  end

  def course_admin?
    enrollment&.course_admin? || false
  end
end
