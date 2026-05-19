require 'rails_helper'

RSpec.describe HomeController, type: :controller do
  describe 'GET #index' do
    context 'when no user is logged in' do
      it 'renders the index page' do
        get :index
        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:index)
      end
    end

    context 'when user is logged in' do
      before { session[:user_id] = '12345' }

      it 'redirects to courses_path' do
        get :index
        expect(response).to redirect_to(courses_path)
      end
    end

    context 'Google login button visibility' do
      render_views

      around do |example|
        original_id     = ENV['GOOGLE_CLIENT_ID']
        original_secret = ENV['GOOGLE_CLIENT_SECRET']
        example.run
        ENV['GOOGLE_CLIENT_ID']     = original_id
        ENV['GOOGLE_CLIENT_SECRET'] = original_secret
      end

      it 'shows the Login with Google button when Google OAuth is configured' do
        ENV['GOOGLE_CLIENT_ID']     = 'fake-id'
        ENV['GOOGLE_CLIENT_SECRET'] = 'fake-secret'
        get :index
        expect(response.body).to include('Login with Google')
        expect(response.body).to include('/auth/google_oauth2')
      end

      it 'hides the Login with Google button when env vars are not set' do
        ENV['GOOGLE_CLIENT_ID']     = nil
        ENV['GOOGLE_CLIENT_SECRET'] = nil
        get :index
        expect(response.body).not_to include('Login with Google')
      end
    end
  end
end
