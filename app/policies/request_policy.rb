class RequestPolicy < ApplicationPolicy
  # record is a Request

  def index?
    enrolled? || site_admin?
  end

  def show?
    staff? || owner? || site_admin?
  end

  def new?
    enrolled? || site_admin?
  end

  def create?
    enrolled? || site_admin?
  end

  def edit?
    owner? || site_admin?
  end

  def update?
    owner? || site_admin?
  end

  def cancel?
    owner? || staff? || site_admin?
  end

  # Only staff (all TAs + teachers) can approve/reject
  def approve?
    staff? || site_admin?
  end

  def reject?
    staff? || site_admin?
  end

  def mass_approve?
    staff? || site_admin?
  end

  def mass_reject?
    staff? || site_admin?
  end

  # Staff can create requests on behalf of students
  def create_for_student?
    staff? || site_admin?
  end

  def new_for_student?
    staff? || site_admin?
  end

  private

  def course
    record.is_a?(Course) ? record : record.course
  end

  def enrollment
    @enrollment ||= UserToCourse.find_by(user: user, course_id: course.id)
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

  def owner?
    record.respond_to?(:user_id) && record.user_id == user&.id
  end
end
