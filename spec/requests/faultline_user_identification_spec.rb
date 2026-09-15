require 'rails_helper'

# Faultline records the User returned by the controller's `current_user` on
# each error occurrence, and config/initializers/faultline.rb attaches the
# Canvas uid from the session as context and drops the duplicate report Rails
# makes for the same exception. This drives a real request through the whole
# middleware stack to prove all three survive the trip.
RSpec.describe 'Faultline user identification', type: :request do
  let(:canvas_uid) { '424242' }
  let(:auth_hash) do
    OmniAuth::AuthHash.new(
      provider: 'canvas',
      uid: canvas_uid,
      info: { name: 'Faultline Tester', email: 'faultline-tester@example.com' },
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

  before do
    allow_any_instance_of(HomeController).to receive(:index).and_raise(RuntimeError, 'boom')
  end

  def sign_in
    post '/auth/canvas'
    follow_redirect!
  end

  it 'records the signed-in user and their Canvas uid on the occurrence' do
    sign_in
    user = User.find_by!(canvas_uid: canvas_uid)

    expect { get root_path }.to raise_error(RuntimeError, 'boom')
      .and change(Faultline::ErrorOccurrence, :count).by(1)

    occurrence = Faultline::ErrorOccurrence.last
    expect(occurrence.user_id).to eq(user.id)
    expect(occurrence.user_type).to eq('User')
    expect(occurrence.user_identifier).to eq(user.email)
    expect(occurrence.error_contexts.find_by(key: 'canvas_uid').value).to eq(canvas_uid)
  end

  it 'records a single anonymous occurrence for a logged-out request' do
    expect { get root_path }.to raise_error(RuntimeError, 'boom')
      .and change(Faultline::ErrorOccurrence, :count).by(1)

    occurrence = Faultline::ErrorOccurrence.last
    expect(occurrence.user_id).to be_nil
    expect(occurrence.request_url).to end_with('/')
    expect(occurrence.error_contexts.where(key: 'canvas_uid')).to be_empty
  end
end
