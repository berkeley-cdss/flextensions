require 'rails_helper'

RSpec.describe SessionController, type: :controller do
  let(:user_data) do
    {
      'id' => '12345',
      'name' => 'Test User',
      'primary_email' => 'test@example.com',
      'email' => 'test@example.com'
    }
  end

  let(:mock_token) do
    instance_double(OAuth2::AccessToken,
                    token: 'new-token',
                    refresh_token: 'new-refresh',
                    expires_at: 2.hours.from_now.to_i)
  end

  describe 'GET #omniauth_callback' do
    let(:auth_hash) do
      OmniAuth::AuthHash.new(
        provider: 'canvas',
        uid: '12345',
        info: OpenStruct.new(name: 'Test User', email: 'test@example.com'),
        credentials: {
          token: 'fake-token',
          refresh_token: 'fake-refresh',
          expires_at: 1.hour.from_now.to_i
        }
      )
    end

    before do
      # put the fabricated auth hash into the Rack env that the controller sees
      request.env['omniauth.auth'] = auth_hash
    end

    context 'happy path' do
      it 'creates the user, sets session, and redirects to courses' do
        get :omniauth_callback, params: { provider: 'canvas' }  # <= add provider

        user = User.find_by(canvas_uid: '12345')
        expect(user).to be_present
        expect(user.email).to eq('test@example.com')

        expect(session[:user_id]).to eq('12345')
        expect(response).to redirect_to(courses_path)
        expect(flash[:notice]).to include('Logged in!')
      end
    end

    context 'when a different canvas_uid presents an existing account email' do
      let!(:existing_user) { User.create!(email: 'test@example.com', canvas_uid: 'old_uid') }

      it 'refuses the login and redirects to root with an error flash' do
        get :omniauth_callback, params: { provider: 'canvas' }

        expect(existing_user.reload.canvas_uid).to eq('old_uid')
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('could not link your account')
      end
    end

    context 'when no auth hash is present' do
      before { request.env.delete('omniauth.auth') }

      it 'redirects to root with an error flash' do
        get :omniauth_callback, params: { provider: 'canvas' }  # <= add provider

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('Authentication failed. No credentials received.')
      end
    end

    context 'when something inside the callback raises' do
      it 'rescues and redirects with “Invalid credentials”' do
        # Force an exception inside the action (e.g., token save blows up)
        allow_any_instance_of(User).to receive(:save!).and_raise(StandardError)

        get :omniauth_callback, params: { provider: 'canvas' } # <= add provider

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('Authentication failed. Invalid credentials.')
      end
    end
  end

  describe '#canvas_lookup_or_create and #update_user_credential' do
    context 'when user exists by canvas_uid' do
      let!(:existing_user) { User.create!(email: 'old@example.com', canvas_uid: '12345') }

      it 'updates email and LMS credentials' do
        expect do
          controller.send(:canvas_lookup_or_create, user_data, mock_token)
        end.to change { existing_user.reload.email }.from('old@example.com').to('test@example.com')

        creds = existing_user.reload.lms_credentials.first
        expect(creds.token).to eq('new-token')
      end
    end

    context 'when a different canvas_uid presents an already-known email' do
      let!(:existing_user) { User.create!(email: 'test@example.com', canvas_uid: 'old_uid') }

      it 'refuses to re-key the account, returns nil, and leaves it untouched' do
        result = nil
        expect do
          result = controller.send(:canvas_lookup_or_create, user_data, mock_token)
        end.not_to(change { existing_user.reload.canvas_uid })

        expect(result).to be_nil
        expect(existing_user.reload.canvas_uid).to eq('old_uid')
      end
    end

    context 'when user is new' do
      it 'creates the user and LMS credentials' do
        expect do
          controller.send(:canvas_lookup_or_create, user_data, mock_token)
        end.to change(User, :count).by(1)

        user = User.find_by(canvas_uid: '12345')
        expect(user.email).to eq('test@example.com')
        expect(user.lms_credentials.first.token).to eq('new-token')
      end
    end
  end

  describe '#developer_lookup_or_create (masquerade path)' do
    context 'when user exists by email' do
      let!(:existing_user) { User.create!(email: 'test@example.com', canvas_uid: 'old_uid') }

      it 'masquerades by re-keying canvas_uid and updates LMS credentials' do
        expect do
          controller.send(:developer_lookup_or_create, user_data, mock_token)
        end.to change { existing_user.reload.canvas_uid }.from('old_uid').to('12345')

        creds = existing_user.reload.lms_credentials.first
        expect(creds.token).to eq('new-token')
      end
    end

    context 'when user exists by canvas_uid' do
      let!(:existing_user) { User.create!(email: 'old@example.com', canvas_uid: '12345') }

      it 'updates email and LMS credentials' do
        expect do
          controller.send(:developer_lookup_or_create, user_data, mock_token)
        end.to change { existing_user.reload.email }.from('old@example.com').to('test@example.com')
      end
    end

    context 'when user is new' do
      it 'creates the user and LMS credentials' do
        expect do
          controller.send(:developer_lookup_or_create, user_data, mock_token)
        end.to change(User, :count).by(1)

        user = User.find_by(canvas_uid: '12345')
        expect(user.email).to eq('test@example.com')
        expect(user.lms_credentials.first.token).to eq('new-token')
      end
    end

    context 'when developer login is not permitted' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'returns nil without creating a user' do
        result = nil
        expect do
          result = controller.send(:developer_lookup_or_create, user_data, mock_token)
        end.not_to change(User, :count)

        expect(result).to be_nil
      end
    end
  end

  describe '#developer_login_allowed?' do
    it 'is permitted in the test environment' do
      expect(controller.send(:developer_login_allowed?)).to be(true)
    end

    it 'is not permitted in production' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      expect(controller.send(:developer_login_allowed?)).to be(false)
    end
  end

  describe 'GET #omniauth_callback (developer provider)' do
    let(:dev_auth_hash) do
      OmniAuth::AuthHash.new(
        provider: 'developer',
        uid: 'test@example.com',
        info: OpenStruct.new(name: 'Test Developer', email: 'test@example.com'),
        credentials: {
          token: 'dev-token',
          refresh_token: nil,
          expires_at: nil
        }
      )
    end

    before do
      request.env['omniauth.auth'] = dev_auth_hash
    end

    context 'developer provider login with missing credentials' do
      it 'handles nil credentials gracefully' do
        get :omniauth_callback, params: { provider: 'developer' }

        user = User.find_by(canvas_uid: 'test@example.com')
        expect(user).to be_present
        expect(user.email).to eq('test@example.com')

        expect(session[:user_id]).to eq('test@example.com')
        expect(response).to redirect_to(courses_path)
      end

      # test course for dev login
      it 'auto-enrolls developer login users in test course' do
        test_course = Course.create!(course_code: 'DEV101', course_name: 'Test Course', canvas_id: 'dev-001')

        get :omniauth_callback, params: { provider: 'developer' }

        user = User.find_by(canvas_uid: 'test@example.com')
        enrollment = Enrollment.find_by(user_id: user.id, course_id: test_course.id)

        expect(enrollment).to be_present
        expect(enrollment.role).to eq('student')
      end

      it 'stores credentials for developer provider with nil refresh token' do
        get :omniauth_callback, params: { provider: 'developer' }

        user = User.find_by(canvas_uid: 'test@example.com')
        creds = user.lms_credentials.first

        expect(creds.token).to be_present
        expect(creds.refresh_token).to be_nil
      end
    end
  end

  describe 'GET #logout' do
    before do
      session[:user_id] = 'test_user_id'
      session[:username] = 'test_username'
    end

    it 'clears the session and redirects to root path' do
      get :logout
      expect(session[:user_id]).to be_nil
      expect(session[:username]).to be_nil
      expect(response).to redirect_to(root_path)
    end
  end
end
