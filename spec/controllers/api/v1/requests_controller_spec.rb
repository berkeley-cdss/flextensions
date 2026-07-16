require 'rails_helper'

module API
  module V1
    describe RequestsController do
      def json_response
        response.parsed_body
      end

      let(:lms) { Lms.find_or_create_by!(lms_name: 'Canvas') }
      let(:course) { create(:course, course_name: 'Test Course') }
      let(:course_to_lms) { create(:course_to_lms, course: course, lms: lms, external_course_id: '301') }
      let(:assignment) do
        create(:assignment, name: 'Test Assignment', course_to_lms: course_to_lms,
                            external_assignment_id: 'abc123', due_date: 7.days.from_now, late_due_date: 10.days.from_now)
      end
      let(:student) { create(:user, email: 'student@example.com', canvas_uid: '201', name: 'Student One') }
      let(:api_user) { create(:user, email: 'api-user@example.com', canvas_uid: 'api-user-1') }

      let(:valid_params) do
        {
          course_id: course.id,
          lms_id: lms.id,
          assignment_id: assignment.id,
          student_uid: student.canvas_uid,
          new_due_date: 14.days.from_now,
          reason: 'Medical emergency'
        }
      end

      before { session[:user_id] = api_user.canvas_uid }

      describe 'POST /api/v1/courses/:course_id/lmss/:lms_id/assignments/:assignment_id/requests' do
        context 'outside the test environment' do
          before do
            allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
            request.headers['Authorization'] = 'any-token'
          end

          it 'refuses the request with :forbidden and does not write data' do
            expect do
              post :create, params: valid_params
            end.not_to change(Request, :count)

            expect(response).to have_http_status(:forbidden)
            expect(json_response['error']).to eq('This endpoint is not available')
          end
        end

        context 'in the test environment' do
          it 'returns :unauthorized when the Authorization header is missing' do
            expect do
              post :create, params: valid_params
            end.not_to change(Request, :count)

            expect(response).to have_http_status(:unauthorized)
            expect(json_response['error']).to eq('Missing Authorization token')
          end

          it 'passes the guard and creates a request when an Authorization header is present' do
            request.headers['Authorization'] = 'any-token'

            expect do
              post :create, params: valid_params
            end.to change(Request, :count).by(1)

            expect(response).to have_http_status(:created)
            expect(json_response['reason']).to eq('Medical emergency')
          end
        end
      end
    end
  end
end
