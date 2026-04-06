class UserToCoursesController < ApplicationController
  before_action :authenticate_user
  before_action :set_course

  def toggle_allow_extended_requests
    authorize! :can_manage_extended_circumstances?, format: :json
    return if performed?

    @enrollment = @course.user_to_courses.find(params[:id])

    if @enrollment.update(allow_extended_requests: params[:allow_extended_requests])
      render json: { success: true }, status: :ok
    else
      flash[:alert] = "Failed to update enrollment: #{@enrollment.errors.full_messages.to_sentence}"
      render json: { redirect_to: course_path(@course) }, status: :unprocessable_content
    end
  end
end
