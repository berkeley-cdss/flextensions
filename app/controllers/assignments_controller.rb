class AssignmentsController < ApplicationController
  def toggle_enabled
    @assignment = Assignment.find(params[:id])
    course = @assignment.course

    # Authoritative server-side check; never trust a client-supplied role.
    unless staff_user?(course)
      Rails.logger.error "User #{current_user&.id} does not have permission to toggle assignment enabled status"
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
