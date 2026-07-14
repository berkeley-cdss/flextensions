# spec/controllers/assignments_controller_spec.rb
require 'rails_helper'

RSpec.describe AssignmentsController, type: :controller do
  before do
    session[:user_id] = user.canvas_uid
  end

  describe 'POST #toggle_enabled' do
    let!(:user) { User.create!(name: 'Test User', email: 'test@example.com', canvas_uid: '123') }
    let!(:course) { Course.create!(course_name: 'Test Course', canvas_id: '123') }
    let!(:course_to_lms) { CourseToLms.create!(course: course, lms_id: 1, external_course_id: '123') }
    let!(:course_settings) { course.course_settings.tap { |cs| cs.update!(enable_extensions: true) } }
    let!(:assignment) do
      Assignment.create!(
        name: 'Test Assignment',
        course_to_lms: course_to_lms,
        due_date: 3.days.from_now,
        external_assignment_id: 'abc123',
        enabled: false
      )
    end

    context 'when the user is an instructor' do
      before do
        Enrollment.create!(user: user, course: course, role: Enrollment::TEACHER_ROLE)
      end

      it 'updates the enabled status to true' do
        post :toggle_enabled, params: { id: assignment.id, enabled: true }

        expect(response).to have_http_status(:ok)
        expect(assignment.reload.enabled).to be true
      end

      it 'updates the enabled status to false' do
        assignment.update!(enabled: true)

        post :toggle_enabled, params: { id: assignment.id, enabled: false }

        expect(response).to have_http_status(:ok)
        expect(assignment.reload.enabled).to be false
      end
    end

    context 'when the user is not an instructor' do
      before do
        Enrollment.create!(user: user, course: course, role: Enrollment::STUDENT_ROLE)
      end

      it 'returns a forbidden status' do
        post :toggle_enabled, params: { id: assignment.id, enabled: true }

        expect(response).to have_http_status(:forbidden)
        expect(assignment.reload.enabled).to be false
      end
    end

    context 'when a student forges an instructor role in the request body' do
      before do
        Enrollment.create!(user: user, course: course, role: Enrollment::STUDENT_ROLE)
      end

      it 'ignores the client-supplied role and returns forbidden' do
        post :toggle_enabled, params: { id: assignment.id, enabled: true, role: 'instructor', user_id: user.id }

        expect(response).to have_http_status(:forbidden)
        expect(assignment.reload.enabled).to be false
      end
    end

    context 'when course-level extensions are disabled' do
      before do
        course_settings.update!(enable_extensions: false)
        Enrollment.create!(user: user, course: course, role: Enrollment::TEACHER_ROLE)
      end

      it 'still allows enabling the assignment and returns ok status' do
        post :toggle_enabled, params: { id: assignment.id, enabled: true }

        expect(response).to have_http_status(:ok)
        expect(assignment.reload.enabled).to be true
      end
    end

    context 'when there is no due_date on an Assignment' do
      before do
        Enrollment.create!(user: user, course: course, role: Enrollment::TEACHER_ROLE)
        assignment.update!(due_date: nil)
      end

      it 'returns a bad request status' do
        post :toggle_enabled, params: { id: assignment.id, enabled: true }

        expect(response).to have_http_status(:unprocessable_content)
        expect(flash[:alert]).to include('Due date must be present if assignment is enabled')
      end
    end
  end
end
