module TokenRefreshable
  extend ActiveSupport::Concern

  # Ensure user has a valid token before making API calls
  def with_valid_token(user)
    token = user.ensure_fresh_canvas_token!

    if token.nil?
      Rails.logger.error "Failed to refresh token for user #{user.id}"
      raise 'Invalid authentication token'
    end

    yield(token)
  end

  private

  def refresh_user_token(user)
    user.canvas_credentials&.refresh!
  end
end
