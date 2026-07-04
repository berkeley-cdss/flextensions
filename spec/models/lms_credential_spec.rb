# spec/models/lms_credential_spec.rb
# == Schema Information
#
# Table name: lms_credentials
#
#  id               :bigint           not null, primary key
#  expire_time      :datetime
#  password         :string
#  refresh_token    :string
#  token            :string
#  username         :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  external_user_id :string
#  lms_id           :bigint
#  user_id          :bigint
#
# Indexes
#
#  index_lms_credentials_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (lms_id => lmss.id)
#  fk_rails_...  (user_id => users.id)
#
require 'rails_helper'

class MockCanvas
  # Simulate authentication using a token and refresh token
  def self.authenticate(token, refresh_token)
    token == 'sensitive_token' && refresh_token == 'sensitive_refresh_token'
  end

  # Simulate retrieving a service, returning 'service_object' if credentials are valid
  def self.mock_get_service(token, refresh_token)
    authenticate(token, refresh_token) ? 'service_object' : nil
  end
end

RSpec.describe LmsCredential, type: :model do
  describe 'Token Encryption' do
    let(:user) { User.create!(email: 'test@example.com') }
    let!(:lms) { Lms.find_or_create_by(id: 1) { |lms| lms.lms_name = 'Canvas'; lms.use_auth_token = true } }
    let!(:credential) do
      described_class.create!(
        user: user,
        lms_id: lms.id,
        username: 'testuser',
        password: 'testpassword',
        token: 'sensitive_token',
        refresh_token: 'sensitive_refresh_token'
      )
    end

    it 'encrypts the token and refresh_token' do
      raw_token = ActiveRecord::Base.connection.execute(
        "SELECT token FROM lms_credentials WHERE id = #{credential.id}"
      ).first['token']
      raw_refresh_token = ActiveRecord::Base.connection.execute(
        "SELECT refresh_token FROM lms_credentials WHERE id = #{credential.id}"
      ).first['refresh_token']

      expect(raw_token).not_to eq 'sensitive_token'
      expect(raw_refresh_token).not_to eq 'sensitive_refresh_token'
      expect(credential.token).to eq 'sensitive_token'
      expect(credential.refresh_token).to eq 'sensitive_refresh_token'
    end

    it 'decrypts the token and refresh_token for use' do
      expect(credential.token).to eq('sensitive_token')
      expect(credential.refresh_token).to eq('sensitive_refresh_token')

      # Simulate a call to get a service object
      expect(MockCanvas.mock_get_service(credential.token, credential.refresh_token)).to eq('service_object')
    end
  end

  describe '#expires_soon?' do
    let(:user) { User.create!(email: 'expiry@example.com') }
    let!(:lms) { Lms.find_or_create_by(id: 1) { |lms| lms.lms_name = 'Canvas'; lms.use_auth_token = true } }
    let(:credential) do
      described_class.create!(user: user, lms_id: lms.id, token: 't', refresh_token: 'r', expire_time: expire_time)
    end

    context 'when the token expires within the buffer' do
      let(:expire_time) { 5.minutes.from_now }

      it 'returns true' do
        expect(credential.expires_soon?).to be true
      end
    end

    context 'when the token expires well in the future' do
      let(:expire_time) { 1.hour.from_now }

      it 'returns false' do
        expect(credential.expires_soon?).to be false
      end
    end

    context 'when there is no expiry time' do
      let(:expire_time) { nil }

      it 'returns false' do
        expect(credential.expires_soon?).to be false
      end
    end
  end

  describe '#refresh!' do
    let(:user) { User.create!(email: 'refresh@example.com') }
    let!(:lms) { Lms.find_or_create_by(id: 1) { |lms| lms.lms_name = 'Canvas'; lms.use_auth_token = true } }
    let(:credential) do
      described_class.create!(
        user: user,
        lms_id: lms.id,
        token: 'old_token',
        refresh_token: 'old_refresh',
        expire_time: 5.minutes.from_now
      )
    end

    it 'persists and returns the new token on success' do
      new_token = instance_double(OAuth2::AccessToken,
                                  token: 'new_token',
                                  refresh_token: 'new_refresh',
                                  expires_at: 1.hour.from_now.to_i)
      allow(OAuth2::AccessToken).to receive(:from_hash).and_return(new_token)
      allow(new_token).to receive(:refresh!).and_return(new_token)

      expect(credential.refresh!).to eq('new_token')
      expect(credential.reload.token).to eq('new_token')
      expect(credential.refresh_token).to eq('new_refresh')
    end

    it 'keeps the old refresh token when Canvas does not rotate it' do
      new_token = instance_double(OAuth2::AccessToken,
                                  token: 'new_token',
                                  refresh_token: nil,
                                  expires_at: 1.hour.from_now.to_i)
      allow(OAuth2::AccessToken).to receive(:from_hash).and_return(new_token)
      allow(new_token).to receive(:refresh!).and_return(new_token)

      credential.refresh!
      expect(credential.reload.refresh_token).to eq('old_refresh')
    end

    it 'returns nil when there is no refresh token' do
      credential.update!(refresh_token: nil)

      expect(credential.refresh!).to be_nil
    end

    it 'returns nil and keeps the credential on a transient failure (no OAuth error code)' do
      fake_response = instance_double(OAuth2::Response, parsed: {}, status: 500, body: 'Internal Server Error')
      allow(OAuth2::AccessToken).to receive(:from_hash).and_raise(OAuth2::Error.new(fake_response))

      expect(credential.refresh!).to be_nil
      expect(credential.reload.token).to eq('old_token')
    end

    it 'returns nil and keeps the credential on a non-grant OAuth error (e.g. misconfigured client)' do
      fake_response = instance_double(OAuth2::Response, status: 401, body: '{"error":"invalid_client"}',
                                                        parsed: { 'error' => 'invalid_client' })
      allow(OAuth2::AccessToken).to receive(:from_hash).and_raise(OAuth2::Error.new(fake_response))

      expect(credential.refresh!).to be_nil
      expect(credential.reload.token).to eq('old_token')
    end

    it 'deletes the credential when Canvas reports the refresh token is dead (invalid_grant)' do
      fake_response = instance_double(OAuth2::Response, status: 400, body: '{"error":"invalid_grant"}',
                                                        parsed: { 'error' => 'invalid_grant',
                                                                  'error_description' => 'refresh_token not found' })
      allow(OAuth2::AccessToken).to receive(:from_hash).and_raise(OAuth2::Error.new(fake_response))

      expect(credential.refresh!).to be_nil
      expect(described_class.exists?(credential.id)).to be false
    end
  end
end
