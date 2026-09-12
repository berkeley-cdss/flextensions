module API
  class BaseController < ActionController::API
    before_action :accessControlAllowOrigin
    before_action :require_api_available!
    before_action :authenticate_api!

    private

    def accessControlAllowOrigin
      response.set_header('Access-Control-Allow-Origin', '*')
    end

    # Master gate for the JSON API. Authenticating a real API caller depends on
    # a token scheme that has not been built yet: no API tokens are issued or
    # validated (see #user_from_api_token), so every token presented today is one
    # that "does not exist." Rather than silently fall back to the shared web
    # session cookie -- which would let any logged-in user reach these write
    # endpoints and, e.g., enroll themselves as course staff -- we refuse every
    # request outside the test environment until real token authentication
    # exists. Specs run in the test environment and continue to exercise the
    # controllers. Genuinely public endpoints (the health-check ping and the API
    # schema) opt out with `skip_before_action :require_api_available!`.
    def require_api_available!
      return if Rails.env.test?

      render json: { error: 'This endpoint is not available' }, status: :forbidden
    end

    # Session/token authentication check, applied after #require_api_available!.
    # In the test environment (the only place the guard above lets requests
    # through) a request is authenticated when it carries the web session cookie
    # or, eventually, a dedicated API token; anything else is rejected with 401.
    # Controllers that are intentionally public opt out with
    # `skip_before_action :authenticate_api!`.
    def authenticate_api!
      return if current_api_user.logged_in?

      render json: { error: 'Unauthorized' }, status: :unauthorized
    end

    # The user making this request. Like ApplicationController#current_user
    # this is never nil -- an unauthenticated request gets a NullUser, which
    # `authenticate_api!` rejects. Memoized so repeated calls do not re-query.
    def current_api_user
      return @current_api_user if defined?(@current_api_user)

      @current_api_user = user_from_session || user_from_api_token || NullUser.new
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
