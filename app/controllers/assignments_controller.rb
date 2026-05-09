class AssignmentsController < ApplicationController
  before_action :authenticate_user

  def toggle_enabled
    @assignment = Assignment.find(params[:id])
    course = @assignment.course_to_lms.course
    @role = course&.user_role(@user)

    unless @role == 'instructor'
      Rails.logger.warn "User #{@user&.id} (role=#{@role.inspect}) attempted to toggle assignment #{@assignment.id} in course #{course&.id}"
      flash.now[:alert] = 'You do not have permission to perform this action.'
      return render json: { redirect_to: course_path(course) }, status: :forbidden
    end

    if @assignment.update(enabled: params[:enabled])
      render json: { success: true }, status: :ok
    else
      flash[:alert] = "Failed to update assignment: #{@assignment.errors.full_messages.to_sentence}"
      render json: { redirect_to: course_path(course) }, status: :unprocessable_content
    end
  end
end
