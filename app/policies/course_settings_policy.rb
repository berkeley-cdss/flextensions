class CourseSettingsPolicy < ApplicationPolicy
  # record is a CourseSettings

  # Only course admins (teacher/leadta) can update settings
  def update?
    course_admin? || site_admin?
  end

  private

  def course
    record.is_a?(Course) ? record : record.course
  end

  def enrollment
    @enrollment ||= UserToCourse.find_by(user: user, course_id: course.id)
  end

  def course_admin?
    enrollment&.course_admin? || false
  end
end
