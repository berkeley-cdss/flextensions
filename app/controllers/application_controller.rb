class ApplicationController < ActionController::Base
  include TokenRefreshable

  before_action :authenticated!, unless: -> { excluded_controller_action? }

  rescue_from LmsFacade::LmsAPIError, with: :handle_lms_api_error

  def excluded_controller_action?
    # Actions and controllers that do NOT require authentication
    excluded_actions = {
      'home' => [ 'index' ],
      'login' => [ 'canvas' ],
      'session' => %w[create omniauth_callback omniauth_failure],
      'rails/health' => [ 'show' ],
      'requests' => [ 'export' ]
    }
    controller = params[:controller]
    action = params[:action]

    excluded_actions[controller]&.include?(action)
  end

  # TODO: Refactor all auth methods
  helper_method :current_user
  def current_user
    if defined?(@current_user)
      @current_user
    else
      @current_user = User.find_by(canvas_uid: session[:user_id])
    end
    # TODO: Remove this line after refactoring all auth methods,
    # and remove other instances of @user in controllers + views
    @user ||= @current_user
  end

  # Because blazer is mounted as a module, `root_path` doesn't seem to work appropriately.
  helper_method :require_admin
  def require_admin
    return if current_user.present? && current_user.admin?

    redirect_to '/', alert: 'You are not authorized to view this page.'
  end

  private
  def authenticate_user
    return true if current_user.present?

    redirect_to root_path, alert: 'You must be logged in to access that page.'
  end

  # TODO: This needs to be refactored.
  def authenticated!
    if session[:user_id].blank? || !Rails.env.test?
      if current_user.nil?
        return handle_authentication_failure('You must be logged in to access that page.')
      elsif current_user.lms_credentials.empty?
        return handle_authentication_failure('User has no credentials.')
      elsif current_user.lms_credentials.first.expire_time < Time.zone.now
        # The Canvas access token has expired. Rather than logging the user out
        # immediately, try to use the stored (long-lived) refresh token to obtain
        # a fresh access token so the session can continue. We only log the user
        # out when there is no refresh token or the refresh actually fails.
        return handle_authentication_failure('You have been logged out.') unless refresh_user_token(current_user)
      end
    end
    true
  rescue StandardError
    handle_authentication_failure('An unexpected error occurred.')
  end

  def handle_authentication_failure(message)
    reset_session
    flash[:alert] = message
    redirect_to root_path
    false
  end

  def handle_lms_api_error(error)
    Rails.logger.error "LMS API Error: #{error.message}"
    # Truncate to 1K characters so we are well short of cookie limits.
    error_message = error.message.truncate(1000)
    flash[:alert] = "An error occurred while communicating with the LMS. Please reach out to flextension@berkeley.edu if you continue to have trouble. Error: #{error_message}"
    redirect_back_or_to(root_path)
  end

  def set_pending_request_count
    return unless defined?(@course) && @course.present? && current_user.present?
    # only calculating pending requests count if the role is instructor so we don't show it to students
    return unless @course.staff_user?(current_user) == 'instructor'

    @pending_requests_count = @course.requests.where(status: 'pending').count
  end

  # Renders a view based on user role, defaulting to current controller and action.
  #
  # You can override the controller or action like so:
  #   render_role_based_view(controller: 'custom_controller', view: 'custom_action')
  #
  # By default, it uses:
  #   controller = controller_name
  #   view       = action_name
  def render_role_based_view(options = {})
    ctrl  = options[:controller] || controller_name
    act   = options[:view] || action_name
    instructor_view = "#{ctrl}/instructor_#{act}"
    student_view = "#{ctrl}/student_#{act}"

    if @course.staff_user?(current_user)
      render instructor_view
    elsif @course.student_user?(current_user)
      render student_view
    else
      redirect_to courses_path, alert: 'You do not have access to this view.'
    end
  end

  protected

  def set_course
    @course = Course.find_by(id: params[:course_id])
    if @course.nil?
      redirect_to courses_path, alert: 'Course not found.' and return
    end
  end

  def require_instructor_role!
    return unless @course && current_user
    return if @course.staff_user?(current_user)

    redirect_to courses_path, alert: 'You do not have access to this page.'
  end
end
