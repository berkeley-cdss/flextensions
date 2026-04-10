class UserToCoursesController < ApplicationController
  before_action :authenticate_user
  before_action :set_course
  before_action :ensure_course_admin

  def toggle_allow_extended_requests
    @enrollment = @course.user_to_courses.find(params[:id])

    if @enrollment.update(allow_extended_requests: params[:allow_extended_requests])
      if request.headers["HX-Request"]
        head_with_flash(:ok, :notice, "Extended requests updated successfully.")
      else
        render json: { success: true }, status: :ok
      end
    else
      error_message = "Failed to update enrollment: #{@enrollment.errors.full_messages.to_sentence}"
      if request.headers["HX-Request"]
        head_with_flash(:unprocessable_entity, :alert, error_message)
      else
        flash[:alert] = error_message
        render json: { redirect_to: course_path(@course) }, status: :unprocessable_content
      end
    end
  end

  private

  def ensure_course_admin
    enrollment = @course.user_to_courses.find_by(user: @user)
    return if enrollment&.course_admin?

    render json: { error: 'You must be an instructor or Lead TA.', redirect_to: course_path(@course) }, status: :forbidden
  end

  def head_with_flash(status, flash_type, message)
    trigger = { flash: { type: flash_type.to_s, message: message } }.to_json
    head status, "HX-Trigger" => trigger
  end
end
