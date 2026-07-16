require 'rails_helper'
module API
  module V1
    describe UsersController do
      let(:api_user) { User.create!(email: 'api-user@example.com', canvas_uid: 'api-user-1') }

      before { session[:user_id] = api_user.canvas_uid }

      describe 'authentication' do
        it 'rejects requests without a session or API token' do
          session[:user_id] = nil

          post :create, params: { email: 'nobody@example.com' }

          expect(response).to have_http_status(:unauthorized)
          expect(response.parsed_body['error']).to eq('Unauthorized')
          expect(User).not_to exist(email: 'nobody@example.com')
        end
      end

      describe 'POST #create' do
        context 'when creating a new user' do
          it 'creates the user successfully' do
            post :create, params: { email: 'test@example.com' }

            expect(response).to have_http_status(:created)
            expect(response.parsed_body['message']).to eq('User created successfully')
            expect(User).to exist(email: 'test@example.com')
          end
        end

        context 'when user with the same email already exists' do
          before do
            User.create(email: 'existing@example.com')
          end

          it 'returns an error message' do
            post :create, params: { email: 'existing@example.com' }

            expect(response).to have_http_status(:conflict)
            expect(response.parsed_body['message']).to eq('A user with this email already exists.')
          end
        end

        context 'when email is missing or invalid' do
          it 'returns an error when email is missing' do
            post :create, params: { email: '' }

            expect(response).to have_http_status(:unprocessable_content)
            expect(response.parsed_body['message']).to eq('Failed to create user')
          end

          it 'returns an error when email is invalid' do
            # Assuming you add email format validation
            post :create, params: { email: 'invalid-email' }

            expect(response).to have_http_status(:unprocessable_content)
            expect(response.parsed_body['message']).to eq('Failed to create user')
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
          delete :destroy, params: { id: 1 }
          expect(response.status).to eq(501)
        end
      end
    end
  end
end
