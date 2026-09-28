require 'rails_helper'

RSpec.describe 'Login redirect', type: :request do
  let(:auth_hash) do
    OmniAuth::AuthHash.new(
      provider: 'canvas',
      uid: 'redirect-test-user',
      info: { name: 'Redirect Test User', email: 'redirect@example.com' },
      credentials: {
        token: 'fake-token',
        refresh_token: 'fake-refresh',
        expires_at: 1.hour.from_now.to_i
      }
    )
  end

  around do |example|
    previous_test_mode = OmniAuth.config.test_mode
    previous_mock_auth = OmniAuth.config.mock_auth[:canvas]
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:canvas] = auth_hash

    example.run
  ensure
    OmniAuth.config.test_mode = previous_test_mode
    OmniAuth.config.mock_auth[:canvas] = previous_mock_auth
  end

  it 'returns to the protected path, including its query string, after login' do
    get new_course_path, params: { canvas_course_id: '123' }
    expect(response).to redirect_to(root_path)

    post '/auth/canvas'
    follow_redirect!

    expect(response).to redirect_to('/courses/new?canvas_course_id=123')
  end
end
