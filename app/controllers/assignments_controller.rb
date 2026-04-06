class AssignmentsController < ApplicationController
  def toggle_enabled
    @assignment = Assignment.find(params[:id])
    authorize! :toggle_enabled, @assignment

    if @assignment.update(enabled: params[:enabled])
      render json: { success: true }, status: :ok
    else
      course = @assignment.course_to_lms.course
      flash[:alert] = "Failed to update assignment: #{@assignment.errors.full_messages.to_sentence}"
      render json: { redirect_to: course_path(course) }, status: :unprocessable_content
    end
  end
end
