# spec/controllers/assignments_controller_spec.rb
require 'rails_helper'

RSpec.describe AssignmentsController, type: :controller do
  let!(:user) { User.create!(name: 'Test User', email: 'test@example.com', canvas_uid: '123') }
  let!(:course) { Course.create!(course_name: 'Test Course', canvas_id: '123') }
  let!(:course_to_lms) { CourseToLms.create!(course: course, lms_id: 1, external_course_id: '123') }
  let!(:course_settings) { CourseSettings.create!(course: course, enable_extensions: true) }
  let!(:assignment) do
    Assignment.create!(
      name: 'Test Assignment',
      course_to_lms: course_to_lms,
      due_date: 3.days.from_now,
      external_assignment_id: 'abc123',
      enabled: false
    )
  end

  before do
    session[:user_id] = user.canvas_uid
    user.lms_credentials.create!(
      lms_name: 'canvas', token: 't', refresh_token: 'r',
      expire_time: 1.hour.from_now
    )
  end

  describe 'POST #toggle_enabled' do
    context 'when the user is an instructor in the course' do
      before { UserToCourse.create!(user: user, course: course, role: 'teacher') }

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

    context 'when course-level extensions are disabled' do
      before do
        UserToCourse.create!(user: user, course: course, role: 'teacher')
        course_settings.update!(enable_extensions: false)
      end

      it 'still allows enabling the assignment and returns ok status' do
        post :toggle_enabled, params: { id: assignment.id, enabled: true }

        expect(response).to have_http_status(:ok)
        expect(assignment.reload.enabled).to be true
      end
    end

    context 'when the assignment has no due_date' do
      before do
        UserToCourse.create!(user: user, course: course, role: 'teacher')
        assignment.update!(due_date: nil)
      end

      it 'returns an unprocessable status' do
        post :toggle_enabled, params: { id: assignment.id, enabled: true }

        expect(response).to have_http_status(:unprocessable_content)
        expect(flash[:alert]).to include('Due date must be present if assignment is enabled')
      end
    end

    # Authorization regression coverage: a client-supplied role parameter
    # must not bypass server-side role lookup. See security audit C1.
    describe 'authorization' do
      context 'when the user is a student in the course' do
        before { UserToCourse.create!(user: user, course: course, role: 'student') }

        it 'rejects the toggle' do
          post :toggle_enabled, params: { id: assignment.id, enabled: true }

          expect(response).to have_http_status(:forbidden)
          expect(assignment.reload.enabled).to be false
        end

        it 'rejects the toggle even when the request claims role=instructor' do
          post :toggle_enabled, params: { id: assignment.id, enabled: true, role: 'instructor' }

          expect(response).to have_http_status(:forbidden)
          expect(assignment.reload.enabled).to be false
        end
      end

      context "when the user is an instructor of a different course" do
        let!(:other_course) { Course.create!(course_name: 'Other Course', canvas_id: '999') }

        before do
          UserToCourse.create!(user: user, course: other_course, role: 'teacher')
        end

        it 'rejects the toggle on the foreign assignment' do
          post :toggle_enabled, params: { id: assignment.id, enabled: true }

          expect(response).to have_http_status(:forbidden)
          expect(assignment.reload.enabled).to be false
        end

        it 'rejects the toggle even when the request claims role=instructor' do
          post :toggle_enabled, params: { id: assignment.id, enabled: true, role: 'instructor' }

          expect(response).to have_http_status(:forbidden)
          expect(assignment.reload.enabled).to be false
        end
      end

      context 'when the user has no enrollment in the course' do
        it 'rejects the toggle even when the request claims role=instructor' do
          post :toggle_enabled, params: { id: assignment.id, enabled: true, role: 'instructor' }

          expect(response).to have_http_status(:forbidden)
          expect(assignment.reload.enabled).to be false
        end
      end
    end
  end
end
