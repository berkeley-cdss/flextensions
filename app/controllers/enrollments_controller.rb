class EnrollmentsController < ApplicationController
  # `authenticated!` from ApplicationController runs before this filter, so
  # `current_user` is populated by the time we get here.
  before_action :set_course
  before_action :ensure_course_staff!
  before_action :set_enrollment

  def toggle_allow_extended_requests
    if @enrollment.update(allow_extended_requests: params[:allow_extended_requests])
      render json: { success: true }, status: :ok
    else
      render json: {
        success: false,
        errors: @enrollment.errors.full_messages,
        redirect_to: courses_path
      }, status: :unprocessable_content
    end
  end

  private

  def set_enrollment
    @enrollment = @course.enrollments.find(params[:id])
  end

  # ApplicationController#ensure_instructor_role would redirect with a flash,
  # which breaks the JSON fetch from the course-settings UI. Respond with 403
  # JSON so the client can surface the failure inline.
  def ensure_course_staff!
    return if @course&staff_user?(current_user)

    render json: {
      success: false,
      error: 'Forbidden',
      redirect_to: courses_path
    }, status: :forbidden
  end
end
