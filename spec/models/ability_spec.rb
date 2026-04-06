# frozen_string_literal: true

require 'rails_helper'
require 'cancan/matchers'

RSpec.describe Ability do
  subject(:ability) { described_class.new(user) }

  let(:course) { create(:course) }
  let(:other_course) { create(:course) }

  # Helper to create a request using the course's existing assignment
  def create_request_for(course, user: nil)
    assignment = course.assignments.first
    attrs = { course: course, assignment: assignment }
    attrs[:user] = user if user
    create(:request, **attrs)
  end

  describe 'unauthenticated user (nil)' do
    let(:user) { nil }

    it 'cannot do anything' do
      expect(ability).not_to be_able_to(:read, course)
      expect(ability).not_to be_able_to(:import, Course)
    end
  end

  describe 'site admin' do
    let(:user) { create(:user, admin: true) }

    it 'can manage everything' do
      expect(ability).to be_able_to(:manage, :all)
    end

    it 'can manage any course' do
      expect(ability).to be_able_to(:manage, course)
    end

    it 'can manage course settings' do
      expect(ability).to be_able_to(:update, course.course_settings)
    end

    it 'can manage form settings' do
      expect(ability).to be_able_to(:update, course.form_setting)
    end

    it 'can import courses' do
      expect(ability).to be_able_to(:import, Course)
    end
  end

  describe 'course admin (teacher)' do
    let(:user) { create(:user) }

    before do
      create(:user_to_course, :as_teacher, user: user, course: course)
    end

    it 'can manage the course' do
      expect(ability).to be_able_to(:manage, course)
    end

    it 'can update course settings' do
      expect(ability).to be_able_to(:update, course.course_settings)
    end

    it 'can update form settings' do
      expect(ability).to be_able_to(:update, course.form_setting)
    end

    it 'can manage requests in the course' do
      request = create_request_for(course)
      expect(ability).to be_able_to(:manage, request)
    end

    it 'can manage assignments in the course' do
      assignment = course.assignments.first
      expect(ability).to be_able_to(:manage, assignment)
    end

    it 'can manage enrollments (UserToCourse) in the course' do
      enrollment = course.user_to_courses.first
      expect(ability).to be_able_to(:toggle_allow_extended_requests, enrollment) if enrollment
    end

    it 'can destroy the course' do
      expect(ability).to be_able_to(:destroy, course)
    end

    it 'can sync assignments' do
      expect(ability).to be_able_to(:sync_assignments, course)
    end

    it 'can sync enrollments' do
      expect(ability).to be_able_to(:sync_enrollments, course)
    end

    it 'can view enrollments' do
      expect(ability).to be_able_to(:enrollments, course)
    end

    it 'can create courses' do
      expect(ability).to be_able_to(:create, Course)
    end

    it 'can import courses' do
      expect(ability).to be_able_to(:import, Course)
    end

    it 'cannot manage a different course' do
      expect(ability).not_to be_able_to(:manage, other_course)
    end

    it 'cannot manage requests in a different course' do
      other_request = create_request_for(other_course)
      expect(ability).not_to be_able_to(:manage, other_request)
    end
  end

  describe 'course admin (lead TA)' do
    let(:user) { create(:user) }

    before do
      create(:user_to_course, :as_leadta, user: user, course: course)
    end

    it 'can manage the course' do
      expect(ability).to be_able_to(:manage, course)
    end

    it 'can update course settings' do
      expect(ability).to be_able_to(:update, course.course_settings)
    end

    it 'can update form settings' do
      expect(ability).to be_able_to(:update, course.form_setting)
    end

    it 'can manage requests' do
      request = create_request_for(course)
      expect(ability).to be_able_to(:approve, request)
      expect(ability).to be_able_to(:reject, request)
    end

    it 'can toggle extended circumstances' do
      student_user = create(:user)
      enrollment = create(:user_to_course, user: student_user, course: course, role: 'student')
      expect(ability).to be_able_to(:toggle_allow_extended_requests, enrollment)
    end

    it 'can create courses' do
      expect(ability).to be_able_to(:create, Course)
    end
  end

  describe 'regular TA' do
    let(:user) { create(:user) }

    before do
      create(:user_to_course, :as_ta, user: user, course: course)
    end

    it 'can read the course' do
      expect(ability).to be_able_to(:read, course)
    end

    it 'can sync assignments' do
      expect(ability).to be_able_to(:sync_assignments, course)
    end

    it 'can sync enrollments' do
      expect(ability).to be_able_to(:sync_enrollments, course)
    end

    it 'can view enrollments' do
      expect(ability).to be_able_to(:enrollments, course)
    end

    it 'can read requests' do
      request = create_request_for(course)
      expect(ability).to be_able_to(:read, request)
    end

    it 'can approve requests' do
      request = create_request_for(course)
      expect(ability).to be_able_to(:approve, request)
    end

    it 'can reject requests' do
      request = create_request_for(course)
      expect(ability).to be_able_to(:reject, request)
    end

    it 'can create requests for students' do
      expect(ability).to be_able_to(:create_for_student, Request.new(course: course))
    end

    it 'can toggle assignment enabled status' do
      assignment = course.assignments.first
      expect(ability).to be_able_to(:toggle_enabled, assignment)
    end

    it 'can read assignments' do
      assignment = course.assignments.first
      expect(ability).to be_able_to(:read, assignment)
    end

    it 'can create courses' do
      expect(ability).to be_able_to(:create, Course)
    end

    it 'can import courses' do
      expect(ability).to be_able_to(:import, Course)
    end

    it 'cannot update course settings' do
      expect(ability).not_to be_able_to(:update, course.course_settings)
    end

    it 'cannot update form settings' do
      expect(ability).not_to be_able_to(:update, course.form_setting)
    end

    it 'cannot destroy the course' do
      expect(ability).not_to be_able_to(:destroy, course)
    end

    it 'cannot update the course' do
      expect(ability).not_to be_able_to(:update, course)
    end

    it 'cannot toggle extended circumstances' do
      student_user = create(:user)
      enrollment = create(:user_to_course, user: student_user, course: course, role: 'student')
      expect(ability).not_to be_able_to(:toggle_allow_extended_requests, enrollment)
    end

    it 'cannot manage a different course' do
      expect(ability).not_to be_able_to(:read, other_course)
    end
  end

  describe 'student' do
    let(:user) { create(:user) }
    let(:other_student) { create(:user) }

    before do
      create(:user_to_course, :as_student, user: user, course: course)
      create(:user_to_course, :as_student, user: other_student, course: course)
    end

    it 'can read the course' do
      expect(ability).to be_able_to(:read, course)
    end

    it 'can read assignments' do
      assignment = course.assignments.first
      expect(ability).to be_able_to(:read, assignment)
    end

    it 'can create own requests' do
      expect(ability).to be_able_to(:create, Request.new(course: course, user: user))
    end

    it 'can read own requests' do
      request = create_request_for(course, user: user)
      expect(ability).to be_able_to(:read, request)
    end

    it 'can update own requests' do
      request = create_request_for(course, user: user)
      expect(ability).to be_able_to(:update, request)
    end

    it 'can cancel own requests' do
      request = create_request_for(course, user: user)
      expect(ability).to be_able_to(:cancel, request)
    end

    it 'cannot read other students\' requests' do
      other_request = create_request_for(course, user: other_student)
      expect(ability).not_to be_able_to(:read, other_request)
    end

    it 'cannot update other students\' requests' do
      other_request = create_request_for(course, user: other_student)
      expect(ability).not_to be_able_to(:update, other_request)
    end

    it 'cannot approve requests' do
      request = create_request_for(course, user: user)
      expect(ability).not_to be_able_to(:approve, request)
    end

    it 'cannot reject requests' do
      request = create_request_for(course, user: user)
      expect(ability).not_to be_able_to(:reject, request)
    end

    it 'cannot update course settings' do
      expect(ability).not_to be_able_to(:update, course.course_settings)
    end

    it 'cannot update form settings' do
      expect(ability).not_to be_able_to(:update, course.form_setting)
    end

    it 'cannot toggle assignment enabled status' do
      assignment = course.assignments.first
      expect(ability).not_to be_able_to(:toggle_enabled, assignment)
    end

    it 'cannot destroy the course' do
      expect(ability).not_to be_able_to(:destroy, course)
    end

    it 'cannot sync assignments' do
      expect(ability).not_to be_able_to(:sync_assignments, course)
    end

    it 'cannot sync enrollments' do
      expect(ability).not_to be_able_to(:sync_enrollments, course)
    end

    it 'cannot create courses' do
      expect(ability).not_to be_able_to(:create, Course)
    end

    it 'can import courses (view import page)' do
      expect(ability).to be_able_to(:import, Course)
    end

    it 'cannot toggle extended circumstances' do
      enrollment = course.user_to_courses.find_by(user: user)
      expect(ability).not_to be_able_to(:toggle_allow_extended_requests, enrollment)
    end

    it 'cannot access a different course' do
      expect(ability).not_to be_able_to(:read, other_course)
    end
  end

  describe 'user with no enrollments' do
    let(:user) { create(:user) }

    it 'can view the import page' do
      expect(ability).to be_able_to(:import, Course)
    end

    it 'cannot create courses' do
      expect(ability).not_to be_able_to(:create, Course)
    end

    it 'cannot read any course' do
      expect(ability).not_to be_able_to(:read, course)
    end
  end

  describe 'user with multiple roles across courses' do
    let(:user) { create(:user) }

    before do
      create(:user_to_course, :as_teacher, user: user, course: course)
      create(:user_to_course, :as_student, user: user, course: other_course)
    end

    it 'can manage the course where they are a teacher' do
      expect(ability).to be_able_to(:manage, course)
    end

    it 'can only read the course where they are a student' do
      expect(ability).to be_able_to(:read, other_course)
      expect(ability).not_to be_able_to(:update, other_course)
    end

    it 'can update settings for teacher course but not student course' do
      expect(ability).to be_able_to(:update, course.course_settings)
      expect(ability).not_to be_able_to(:update, other_course.course_settings)
    end
  end

  describe 'removed enrollment' do
    let(:user) { create(:user) }

    before do
      create(:user_to_course, :as_teacher, user: user, course: course, removed: true)
    end

    it 'cannot access the course' do
      expect(ability).not_to be_able_to(:read, course)
    end

    it 'cannot manage the course' do
      expect(ability).not_to be_able_to(:manage, course)
    end
  end
end
