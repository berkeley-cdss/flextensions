module Authorization
  extend ActiveSupport::Concern

  included do
    helper_method :current_policy
  end

  private

  def current_policy
    @current_policy ||= CoursePolicy.new(current_user, @course)
  end

  # Authorize an action using CoursePolicy. Redirects or renders 403 on failure.
  #
  # When used as a before_action, Rails automatically halts the filter chain
  # after a redirect/render. When used inline in an action method, the caller
  # must add `return if performed?` after the call to prevent double renders.
  #
  # Usage:
  #   before_action -> { authorize! :can_manage_settings? }
  #   # or define a named method:
  #   def authorize_manage_settings = authorize!(:can_manage_settings?)
  #
  # Inline usage:
  #   authorize! :can_edit_course?
  #   return if performed?
  def authorize!(permission, format: nil)
    return if current_policy.public_send(permission)

    deny_access!(format: format)
  end

  def deny_access!(format: nil, message: 'You do not have permission to perform this action.')
    format ||= request.format.symbol

    if format == :json
      render json: { error: message, redirect_to: fallback_redirect_path }, status: :forbidden
    else
      redirect_to(fallback_redirect_path, alert: message)
    end
  end

  def fallback_redirect_path
    @course ? course_path(@course) : courses_path
  end
end
