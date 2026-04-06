class CoursePolicy < ApplicationPolicy
  # record is a Course

  # Anyone enrolled or site admin can see the course list
  def index?
    user.present?
  end

  def show?
    enrolled? || site_admin?
  end

  # Everyone can view the import course page
  def new?
    user.present?
  end

  # Any TA/instructor can create (import) a course
  def create?
    user.present?
  end

  # Only course admins (teacher/leadta) and site admins
  def edit?
    course_admin? || site_admin?
  end

  def enrollments?
    staff? || site_admin?
  end

  def delete?
    course_admin? || site_admin?
  end

  # TAs can sync assignments and enrollments
  def sync_assignments?
    staff? || site_admin?
  end

  def sync_enrollments?
    staff? || site_admin?
  end

  private

  def enrollment
    @enrollment ||= UserToCourse.find_by(user: user, course_id: record.id)
  end

  def enrolled?
    enrollment.present?
  end

  def course_admin?
    enrollment&.course_admin? || false
  end

  def staff?
    enrollment&.staff? || false
  end
end
