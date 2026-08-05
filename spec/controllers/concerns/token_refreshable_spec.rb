require 'rails_helper'

RSpec.describe TokenRefreshable, type: :controller do
  controller(ApplicationController) do
    # rubocop:disable RSpec/DescribedClass
    include TokenRefreshable
    # rubocop:enable RSpec/DescribedClass

    def dummy_action
      with_valid_token(current_user) do |token|
        render plain: "Token: #{token}"
      end
    end

    private

    def current_user
      @current_user ||= User.find(session[:user_id])
    end
  end

  let(:expire_time) { 1.hour.from_now }
  let(:user) do
    User.create!(email: 'test@example.com', canvas_uid: '123').tap do |u|
      Lms.find_or_create_by(id: 1) { |l| l.lms_name = 'Canvas'; l.use_auth_token = true }
      u.lms_credentials.create!(
        lms_id: 1,
        token: 'valid_token',
        refresh_token: 'refresh_token',
        expire_time: expire_time
      )
    end
  end

  before do
    routes.draw { get 'dummy_action' => 'anonymous#dummy_action' }
    session[:user_id] = user.id
  end

  describe '#with_valid_token' do
    context 'when token is not expiring soon' do
      it 'yields with current token' do
        get :dummy_action
        expect(response.body).to eq('Token: valid_token')
      end
    end

    context 'when token is expiring soon and refresh succeeds' do
      let(:expire_time) { 5.minutes.from_now }

      it 'refreshes token and yields with new token' do
        new_token = instance_double(OAuth2::AccessToken,
                                    token: 'refreshed_token',
                                    refresh_token: 'new_refresh',
                                    expires_at: 1.hour.from_now.to_i)

        allow(OAuth2::AccessToken).to receive(:from_hash).and_return(new_token)
        allow(new_token).to receive(:refresh!).and_return(new_token)

        get :dummy_action
        expect(response.body).to eq('Token: refreshed_token')
        expect(user.lms_credentials.first.reload.token).to eq('refreshed_token')
      end
    end

    context 'when token is expiring soon and refresh fails' do
      let(:expire_time) { 5.minutes.from_now }

      it 'raises an error and logs it' do
        fake_response = instance_double(OAuth2::Response, parsed: {}, status: 401)
        allow(OAuth2::AccessToken).to receive(:from_hash).and_raise(OAuth2::Error.new(fake_response))

        expect { get :dummy_action }.to raise_error('Invalid authentication token')
      end
    end

    context 'when the user has no Canvas credentials' do
      it 'raises an error' do
        user.lms_credentials.destroy_all

        expect { get :dummy_action }.to raise_error('Invalid authentication token')
      end
    end
  end
end
