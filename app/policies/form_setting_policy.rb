class FormSettingPolicy < ApplicationPolicy
  # record is a FormSetting

  # Only course admins (teacher/leadta) can edit/update form settings
  def edit?
    course_admin? || site_admin?
  end

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
