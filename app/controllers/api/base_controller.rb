module API
  class BaseController < ActionController::API
    before_action :accessControlAllowOrigin
    before_action :authenticate_api!

    private

    def accessControlAllowOrigin
      response.set_header('Access-Control-Allow-Origin', '*')
    end

    # Gate for the JSON API. A request is authenticated when it carries either
    # the web session cookie (a logged-in user) or, eventually, a dedicated API
    # token. Anything else is rejected with 401 so the write endpoints below are
    # no longer reachable anonymously. Controllers that are intentionally public
    # (health checks, the API schema) opt out with
    # `skip_before_action :authenticate_api!`.
    def authenticate_api!
      return if current_api_user.present?

      render json: { error: 'Unauthorized' }, status: :unauthorized
    end

    # The user making this request, or nil when it is unauthenticated. Memoized
    # (including the nil result) so repeated calls do not re-query.
    def current_api_user
      return @current_api_user if defined?(@current_api_user)

      @current_api_user = user_from_session || user_from_api_token
    end

    # Resolves the user from the shared web session cookie, using the same
    # canvas_uid lookup as ApplicationController#current_user.
    def user_from_session
      return nil if session[:user_id].blank?

      User.find_by(canvas_uid: session[:user_id])
    end

    # Placeholder for token-based API authentication. Tokens are not yet issued
    # or validated, so for now this authenticates no one; a token-only caller is
    # treated as unauthenticated. Replace this with real token lookup when the
    # API token feature is built.
    def user_from_api_token
      nil
    end
  end
end
