require 'rails_helper'

# The export endpoint is public and authenticated solely by the course's
# read-only API token (no user session), so it lives in its own controller and
# is exercised here as a request spec against the real route.
RSpec.describe 'Request exports', type: :request do
  let(:course) { create(:course, course_name: 'Test Course', course_code: 'TST101') }
  let(:student) { User.create!(email: 'student@example.com', canvas_uid: '123', name: 'Student') }
  let(:instructor) { User.create!(email: 'instructor@example.com', canvas_uid: '566', name: 'Instructor') }
  let(:assignment) do
    Assignment.create!(
      name: 'A1',
      course_to_lms_id: course.course_to_lms(1).id,
      external_assignment_id: 'x1',
      due_date: 2.days.from_now,
      enabled: true
    )
  end

  it 'returns a CSV of requests when the token is valid' do
    Request.create!(user: student, course: course, assignment: assignment,
                    reason: 'Need more time', requested_due_date: 4.days.from_now, status: 'pending')

    get export_course_requests_path(course), params: { readonly_api_token: course.readonly_api_token }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/csv')
    expect(response.body).to include('Student')
    expect(response.body).to include('A1')
  end

  it 'filters the export by status when requested' do
    Request.create!(user: student, course: course, assignment: assignment,
                    reason: 'Pending one', requested_due_date: 4.days.from_now, status: 'pending')
    Request.create!(user: instructor, course: course, assignment: assignment,
                    reason: 'Approved one', requested_due_date: 4.days.from_now, status: 'approved')

    get export_course_requests_path(course), params: { readonly_api_token: course.readonly_api_token, status: 'approved' }

    expect(response.body).to include('Instructor')
    expect(response.body).to include('approved')
    expect(response.body).not_to include('pending')
  end

  it 'rejects an invalid token' do
    get export_course_requests_path(course), params: { readonly_api_token: 'wrong-token' }

    expect(response).to have_http_status(:unauthorized)
    expect(response.body).to include('Invalid or missing API token')
  end

  it 'rejects a missing token' do
    get export_course_requests_path(course)

    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects a request for a non-existent course' do
    get export_course_requests_path(course_id: 0), params: { readonly_api_token: 'anything' }

    expect(response).to have_http_status(:unauthorized)
  end
end
