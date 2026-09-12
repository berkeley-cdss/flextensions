require 'rails_helper'
module API
  module V1
    describe CoursesController do
      let(:api_user) { User.create!(email: 'api-user@example.com', canvas_uid: 'api-user-1') }

      before { session[:user_id] = api_user.canvas_uid }

      describe 'availability guard outside the test environment' do
        before do
          allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        end

        it 'refuses #create with :forbidden and does not write data' do
          expect do
            post :create, params: { course_name: 'Blocked Course' }
          end.not_to change(Course, :count)

          expect(response).to have_http_status(:forbidden)
          expect(response.parsed_body['error']).to eq('This endpoint is not available')
        end

        it 'refuses #add_user with :forbidden and does not create an enrollment' do
          course = Course.create!(course_name: 'Guarded Course')
          user = User.create!(email: 'guarded@example.com')

          expect do
            post :add_user, params: { course_id: course.id, user_id: user.id, role: 'teacher' }
          end.not_to change(Enrollment, :count)

          expect(response).to have_http_status(:forbidden)
          expect(response.parsed_body['error']).to eq('This endpoint is not available')
        end
      end

      describe 'POST #create' do
        context 'when the new course is successfully created' do
          let(:course_name) { 'New Course' }

          it 'creates and saves a new course' do
            post :create, params: { course_name: course_name }

            expect(response).to have_http_status(:created)
            expect(Course.find_by(course_name: course_name)).to be_present
            expect(flash[:success]).to eq('Course created successfully')
            expect(response.parsed_body['course_name']).to eq('New Course')
          end
        end

        context 'when a course with the same name already exists' do
          let!(:existing_course) { Course.create(course_name: 'Existing Course') }

          it 'does not create a new course with the same name and returns an error' do
            post :create, params: { course_name: existing_course.course_name }

            expect(Course.find_by(course_name: existing_course.course_name)).to be_present
            expect(response).to have_http_status(:unprocessable_content)
            expect(response.parsed_body).to eq({ 'message' => 'A course with the same course name already exists.' })
          end
        end
      end

      describe 'index' do
        it 'throws a 501 error' do
          get :index
          expect(response.status).to eq(501)
        end
      end

      describe 'destroy' do
        it 'throws a 501 error' do
          delete :destroy, params: { id: 16 }
          expect(response.status).to eq(501)
        end
      end

      describe 'add_user' do
        let(:test_course) { Course.create(course_name: 'Test Course') }
        let(:test_user) { User.create!(email: 'testuniqueuser@example.com') }

        context 'Provided parameters are valid' do
          it 'adds an existing user to an existing course' do
            post :add_user, params: { course_id: test_course.id, user_id: test_user.id, role: 'ta' }
            expect(response).to have_http_status(:created)
            expect(flash['success']).to eq('User added to the course successfully.')
          end
        end

        context 'Provided parameter are invalid' do
          it 'returns an error if course is not existed in the courses table' do
            post :add_user, params: { course_id: 123_456, user_id: test_user.id, role: 'ta' }
            expect(response).to have_http_status(:not_found)
            expect(response.parsed_body['error']).to eq('The course does not exist.')
          end

          it 'returns an error if user is not existed in the users table' do
            post :add_user, params: { course_id: test_course.id, user_id: 123_456, role: 'ta' }
            expect(response).to have_http_status(:not_found)
            expect(response.parsed_body['error']).to eq('The user does not exist.')
          end

          it 'returns an error if the user is already associated with the course' do
            post :add_user, params: { course_id: test_course.id, user_id: test_user.id, role: 'student' }
            post :add_user, params: { course_id: test_course.id, user_id: test_user.id, role: 'student' }
            expect(response).to have_http_status(:unprocessable_content)
            expect(response.parsed_body['error']).to eq('The user is already added to the course.')
          end
        end
      end
    end
  end
end
