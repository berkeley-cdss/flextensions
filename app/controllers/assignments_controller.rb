class AssignmentsController < ApplicationController
  def toggle_enabled
    @assignment = Assignment.find(params[:id])
    @course = @assignment.course_to_lms.course
    @role = @course&.user_role(current_user)

    authorize! :can_toggle_assignment?, format: :json
    return if performed?

    if @assignment.update(enabled: params[:enabled])
      render json: { success: true }, status: :ok
    else
      flash[:alert] = "Failed to update assignment: #{@assignment.errors.full_messages.to_sentence}"
      render json: { redirect_to: course_path(@course) }, status: :unprocessable_content
    end
  end
end
