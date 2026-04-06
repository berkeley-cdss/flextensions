# Centralized RBAC authorization for course-scoped actions.
#
# Roles (highest to lowest privilege):
#   - site_admin: User.admin? flag, can do everything
#   - course_admin: teacher or leadta enrollment, can manage everything in a course
#   - ta: regular TA enrollment, can view everything, approve/deny requests, sync
#   - student: can only manage their own extensions
#
# Usage:
#   policy = CoursePolicy.new(user, course)
#   policy.can_manage_settings?  # => true/false
class CoursePolicy
  attr_reader :user, :course, :enrollments

  def initialize(user, course = nil)
    @user = user
    @course = course
    @enrollments = if course && user
                     course.user_to_courses.where(user: user)
                   else
                     UserToCourse.none
                   end
  end

  # --- Role checks ---

  def site_admin?
    user&.admin?
  end

  def course_admin?
    site_admin? || enrollments.any?(&:course_admin?)
  end

  def staff?
    site_admin? || enrollments.any?(&:staff?)
  end

  def student?
    enrollments.any?(&:student?)
  end

  def enrolled?
    enrollments.exists?
  end

  # Returns the view-level role used for rendering (instructor/student views).
  # This preserves the existing dual-view rendering pattern.
  def view_role
    return 'instructor' if staff?
    return 'student' if student?

    nil
  end

  # --- Course-level permissions ---

  # Everyone can view the import course page (courses#new)
  def can_view_import_page?
    user.present?
  end

  # Any authenticated user can create/import courses.
  # Canvas API enrollment filtering determines which courses appear.
  def can_create_course?
    user.present?
  end

  # Enrolled users can view a course (students only if extensions enabled)
  def can_view_course?
    site_admin? || enrolled?
  end

  # Only course admins (teacher/leadta) can edit course settings
  def can_edit_course?
    course_admin?
  end

  # Only course admins can delete a course
  def can_delete_course?
    course_admin?
  end

  # Staff can view enrollments, but only course admins can modify them
  def can_view_enrollments?
    staff?
  end

  # Staff can sync assignments from Canvas
  def can_sync_assignments?
    staff?
  end

  # Staff can sync enrollments from Canvas
  def can_sync_enrollments?
    staff?
  end

  # --- Request permissions ---

  # Enrolled users can view requests (scoped by role in controller)
  def can_view_requests?
    site_admin? || enrolled?
  end

  # Students can create requests for themselves; staff can create for students
  def can_create_request?
    site_admin? || enrolled?
  end

  # Staff can create requests on behalf of students
  def can_create_request_for_student?
    staff?
  end

  # Staff can approve or deny requests (including regular TAs)
  def can_approve_or_deny_requests?
    staff?
  end

  # Only staff can cancel (delete) requests. Students cannot cancel requests.
  def can_cancel_request?
    staff?
  end

  # --- Settings permissions (course admins only, NOT regular TAs) ---

  # Only course admins can update course settings
  def can_manage_settings?
    course_admin?
  end

  # Only course admins can update form settings
  def can_manage_form_settings?
    course_admin?
  end

  # Only course admins can toggle extended circumstances status
  def can_manage_extended_circumstances?
    course_admin?
  end

  # --- Assignment permissions ---

  # Only course admins can toggle assignment enabled status (a configuration action)
  def can_toggle_assignment?
    course_admin?
  end
end
