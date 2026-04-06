# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user

    # All logged-in users can view the course import page
    can :import, Course

    # Site admins can do everything
    if user.admin?
      can :manage, :all
      return
    end

    # Any staff member (in any course) can create/import courses
    can :create, Course if user.user_to_courses.where(role: UserToCourse.staff_roles).exists?

    # Course-specific permissions based on enrollments
    user.user_to_courses.where(removed: false).find_each do |enrollment|
      case enrollment.role
      when 'teacher', 'leadta'
        grant_course_admin_abilities(enrollment.course_id)
      when 'ta'
        grant_ta_abilities(enrollment.course_id)
      when 'student'
        grant_student_abilities(user.id, enrollment.course_id)
      end
    end
  end

  private

  # Course admins (instructors and lead TAs) can manage everything in their course
  def grant_course_admin_abilities(course_id)
    can :manage, Course, id: course_id
    can :manage, Request, course_id: course_id
    can :manage, Assignment, course_to_lms: { course_id: course_id }
    can :manage, CourseSettings, course_id: course_id
    can :manage, FormSetting, course_id: course_id
    can :manage, UserToCourse, course_id: course_id
  end

  # Regular TAs can view everything, approve/deny requests, and sync.
  # They cannot update settings or toggle extended circumstances.
  def grant_ta_abilities(course_id)
    can :read, Course, id: course_id
    can [:sync_assignments, :sync_enrollments, :enrollments], Course, id: course_id

    can [:read, :create, :approve, :reject, :create_for_student, :export], Request, course_id: course_id

    can [:read, :toggle_enabled], Assignment, course_to_lms: { course_id: course_id }

    can :read, CourseSettings, course_id: course_id
    can :read, FormSetting, course_id: course_id
    can :read, UserToCourse, course_id: course_id
  end

  # Students can only manage their own requests within a course
  def grant_student_abilities(user_id, course_id)
    can :read, Course, id: course_id

    can [:read, :create, :update, :cancel], Request, course_id: course_id, user_id: user_id

    can :read, Assignment, course_to_lms: { course_id: course_id }
  end
end
