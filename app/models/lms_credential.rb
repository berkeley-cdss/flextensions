# app/models/lms_credential.rb
# == Schema Information
#
# Table name: lms_credentials
#
#  id               :bigint           not null, primary key
#  expire_time      :datetime
#  lms_name         :string
#  password         :string
#  refresh_token    :string
#  token            :string
#  username         :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  external_user_id :string
#  user_id          :bigint
#
# Indexes
#
#  index_lms_credentials_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class LmsCredential < ApplicationRecord
  # Belongs to a User
  belongs_to :user

  # Encryption for tokens
  encrypts :token, :refresh_token

  # LMS must exist
  validates :lms_name, presence: true

  # Whether the access token expires within the given buffer (so callers can
  # refresh it before starting a batch of API calls).
  def expires_soon?(buffer = 15.minutes)
    expire_time.present? && Time.zone.now + buffer > expire_time
  end

  # Exchanges the stored refresh token for a new access token and persists it.
  # Returns the new access token, or nil when there is no refresh token or
  # Canvas rejects the refresh (e.g. the user revoked Flextensions' access).
  #
  # When Canvas reports the refresh token itself is dead (invalid_grant), the
  # credential is deleted so nothing keeps retrying it: the user simply goes
  # through OAuth again on their next visit, and auto-approval stops offering
  # them as a candidate. Transient failures (network errors, outages, a
  # misconfigured client) leave the credential untouched.
  def refresh!
    return nil if refresh_token.blank?

    client = OAuth2::Client.new(
      ENV.fetch('CANVAS_CLIENT_ID', nil),
      ENV.fetch('CANVAS_APP_KEY', nil),
      site: ENV.fetch('CANVAS_URL', nil),
      token_url: '/login/oauth2/token'
    )
    new_token = OAuth2::AccessToken.from_hash(client, refresh_token: refresh_token).refresh!

    update(
      token: new_token.token,
      # Canvas does not always rotate refresh tokens; keep the old one then.
      refresh_token: new_token.refresh_token || refresh_token,
      expire_time: Time.zone.at(new_token.expires_at)
    )
    new_token.token
  rescue OAuth2::Error => e
    if e.code == 'invalid_grant'
      # Canvas no longer recognizes this refresh token: the user revoked
      # Flextensions under Settings > Approved Integrations, or the developer
      # key/scopes changed (which invalidates every token derived from the
      # key). It can never work again, so remove it rather than retry it.
      Rails.logger.warn "Removing revoked #{lms_name} credential for user #{user_id} (invalid_grant)"
      destroy
    else
      Rails.logger.error "Failed to refresh #{lms_name} token for user #{user_id}: #{e.message}"
    end
    nil
  end
end
