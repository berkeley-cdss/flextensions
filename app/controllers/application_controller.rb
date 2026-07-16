class ApplicationController < ActionController::Base
  include TokenRefreshable

  # Public actions opt out with `skip_before_action :authenticated!`.
  before_action :authenticated!

  rescue_from LmsFacade::LmsAPIError, with: :handle_lms_api_error

  helper_method :current_user
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.find_by(canvas_uid: session[:user_id])
  end

  # Whether the given user is staff (teacher/TA/lead TA) in the given course.
  # Prefer this over comparing role strings like `@role == 'instructor'`.
  # Memoized per request because it issues a query and may be checked from both
  # controllers and views.
  helper_method :staff_user?
  def staff_user?(course = @course, user = current_user)
    return false unless course && user

    @staff_user_cache ||= {}
    @staff_user_cache.fetch([ course.id, user.id ]) do |key|
      @staff_user_cache[key] = course.course_staff?(user)
    end
  end

  # Because blazer is mounted as a module, `root_path` doesn't seem to work appropriately.
  helper_method :require_admin
  def require_admin
    return if current_user.present? && current_user.admin?

    redirect_to '/', alert: 'You are not authorized to view this page.'
  end

  private

  def authenticated!
    return handle_authentication_failure('You must be logged in to access that page.') if current_user.nil?

    # In the test environment a valid session user is treated as fully
    # authenticated so specs don't have to stand up LMS credentials. Production
    # always verifies the Canvas token below.
    return true if Rails.env.test?

    if current_user.lms_credentials.empty?
      return handle_authentication_failure('User has no credentials.')
    elsif current_user.lms_credentials.first.expire_time < Time.zone.now
      # The Canvas access token has expired. Rather than logging the user out
      # immediately, try to use the stored (long-lived) refresh token to obtain
      # a fresh access token so the session can continue. We only log the user
      # out when there is no refresh token or the refresh actually fails.
      return handle_authentication_failure('You have been logged out.') unless refresh_user_token(current_user)
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
    Rails.error.report(error, handled: true,
                       context: { component: 'lms_api', controller: controller_name, action: action_name })
    # Truncate to 1K characters so we are well short of cookie limits.
    error_message = error.message.truncate(1000)
    flash[:alert] = "An error occurred while communicating with the LMS. Please reach out to flextension@berkeley.edu if you continue to have trouble. Error: #{error_message}"
    redirect_back_or_to(root_path)
  end

  def set_pending_request_count
    return unless @course.present? && staff_user?

    @pending_requests_count = @course.requests.where(status: 'pending').count
  end


  protected
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

  def set_course
    @course = Course.find_by(id: params[:course_id])
    if @course.nil?
      redirect_to courses_path, alert: 'Course not found.' and return
    end
  end

  def require_course_staff!
    return if staff_user?

    redirect_to courses_path, alert: 'You do not have access to this page.'
  end
end
