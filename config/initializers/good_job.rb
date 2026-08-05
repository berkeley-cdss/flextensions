Rails.application.config.to_prepare do
  GoodJob::ApplicationController.class_eval do
    # Mirrors ApplicationController#current_user: always a User, with a
    # NullUser standing in for a logged-out visitor.
    def current_user
      @current_user ||= User.find_by(canvas_uid: session[:user_id]) || NullUser.new
    end

    before_action :require_admin

    def require_admin
      if !current_user.logged_in?
        redirect_to '/', alert: 'You must be logged in.'
      elsif !current_user.admin?
        redirect_to '/', alert: 'You are not authorized to view this page.'
      end
    end
  end
end
