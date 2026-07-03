# app/models/user.rb
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
class User < ApplicationRecord
  has_many :requests, dependent: :nullify
  # This association is for when a request is processed by a different user:
  has_many :processed_requests, class_name: 'Request', foreign_key: 'last_processed_by_user_id', inverse_of: :last_processed_by_user

  # NOTE: Validations are skipped when a User is created by SyncUsersFromCanvasJob
  # You should update that job if these validations become complex.
  # In the meantime, we can trust that the data coming from Canvas is valid.
  validates :email, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: 'must be a valid email address' }

  # Associations
  has_many :lms_credentials, dependent: :destroy

  # Relationship with Extension
  has_many :extensions

  # Relationship with Course (and UserToCourse)
  has_many :user_to_courses
  has_many :courses, through: :user_to_courses

  # TODO: We should probably use lms_id over lms_name
  def canvas_credentials
    lms_credentials.find_by(lms_name: 'canvas')
  end

  # Returns a Canvas access token that is valid for at least the next few
  # minutes, refreshing it first when it is about to expire. Returns nil when
  # the user has no Canvas credential or the refresh fails (e.g. a revoked
  # refresh token) -- callers must treat nil as "cannot call Canvas as this
  # user" rather than proceeding with a stale token.
  def ensure_fresh_canvas_token!
    credential = canvas_credentials
    return nil if credential.nil?
    return credential.token unless credential.expires_soon?

    credential.refresh!
  end
end
