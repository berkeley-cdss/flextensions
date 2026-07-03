# spec/models/user_spec.rb
# == Schema Information
#
# Table name: users
#
#  id         :bigint           not null, primary key
#  admin      :boolean          default(FALSE)
#  canvas_uid :string
#  email      :string
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  student_id :string
#
# Indexes
#
#  index_users_on_canvas_uid  (canvas_uid) UNIQUE
#  index_users_on_email       (email) UNIQUE
#
require 'rails_helper'

RSpec.describe User, type: :model do
  describe '#token_expired?' do
    let(:user) { described_class.create!(email: 'test@example.com', canvas_uid: '123') }

    context 'when there are no credentials' do
      it 'returns false' do
        expect(user.token_expired?).to be false
      end
    end

    context 'when the token is still valid' do
      before do
        user.lms_credentials.create!(
          lms_name: 'canvas',
          token: 'valid_token',
          refresh_token: 'refresh_token',
          expire_time: 1.hour.from_now
        )
      end

      it 'returns false' do
        expect(user.token_expired?).to be false
      end
    end

    context 'when the token is expired' do
      before do
        user.lms_credentials.create!(
          lms_name: 'canvas',
          token: 'expired_token',
          refresh_token: 'refresh_token',
          expire_time: 1.hour.ago
        )
      end

      it 'returns true' do
        expect(user.token_expired?).to be true
      end
    end
  end

  describe '#canvas_credentials' do
    let(:user) { described_class.create!(email: 'test@example.com', canvas_uid: '123') }

    it 'returns the correct credentials for a user' do
      user.lms_credentials.create!(
        lms_name: 'canvas',
        token: 'valid_token',
        refresh_token: 'refresh_token',
        expire_time: 1.hour.from_now
      )

      credentials = user.canvas_credentials
      expect(credentials).to be_an_instance_of(LmsCredential)
    end
  end

  describe '#ensure_fresh_canvas_token!' do
    let(:user) { described_class.create!(email: 'test@example.com', canvas_uid: '123') }

    context 'when the user has no Canvas credential' do
      it 'returns nil' do
        expect(user.ensure_fresh_canvas_token!).to be_nil
      end
    end

    context 'when token does not expire soon' do
      before do
        user.lms_credentials.create!(
          lms_name: 'canvas',
          token: 'valid_token',
          refresh_token: 'refresh_token',
          expire_time: 1.hour.from_now
        )
      end

      it 'returns the current token without refreshing' do
        expect_any_instance_of(SessionController).not_to receive(:refresh_user_token)
        expect(user.ensure_fresh_canvas_token!).to eq('valid_token')
      end
    end

    context 'when token expires soon and is refreshed' do
      let!(:credential) do
        user.lms_credentials.create!(
          lms_name: 'canvas',
          token: 'stale_token',
          refresh_token: 'refresh_token',
          expire_time: 5.minutes.from_now
        )
      end

      # Simulate the real SessionController#refresh_user_token, which persists a
      # fresh token to the credential row when the refresh succeeds.
      before do
        allow(user).to receive(:token_expires_soon?).and_return(true)
        allow_any_instance_of(SessionController).to receive(:refresh_user_token) do
          credential.update!(token: 'refreshed_token', expire_time: 1.hour.from_now)
          'refreshed_token'
        end
      end

      it 'returns the refreshed token, not the stale one' do
        # Regression: previously this returned the stale in-memory token even
        # after a successful refresh, so callers (e.g. the roster sync job and
        # auto-approval) posted to Canvas with an about-to-expire token.
        expect(user.ensure_fresh_canvas_token!).to eq('refreshed_token')
      end
    end

    context 'when the Canvas credential is not the first credential' do
      before do
        # A non-Canvas credential ordered ahead of the Canvas one; the previous
        # implementation grabbed lms_credentials.first and returned the wrong token.
        user.lms_credentials.create!(lms_name: 'other', token: 'other_token', expire_time: 1.hour.from_now)
        user.lms_credentials.create!(
          lms_name: 'canvas',
          token: 'canvas_token',
          refresh_token: 'refresh_token',
          expire_time: 1.hour.from_now
        )
      end

      it 'returns the Canvas token' do
        expect(user.ensure_fresh_canvas_token!).to eq('canvas_token')
      end
    end
  end
end
