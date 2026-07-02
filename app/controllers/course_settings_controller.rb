class CourseSettingsController < ApplicationController
  before_action :authenticated!
  before_action :authenticate_user
  before_action :set_course
  before_action :ensure_instructor_role
  before_action :set_pending_request_count

  # Default template settings
  DEFAULT_EMAIL_SUBJECT = 'Extension Request Status: {{status}} - {{course_code}}'.freeze
  DEFAULT_EMAIL_TEMPLATE = "Dear {{student_name}},\n\n
  Your extension request for {{assignment_name}} in {{course_name}} ({{course_code}}) has been {{status}}.
  \n\nExtension Details:
  \n- Original Due Date: {{original_due_date}}
  \n- New Due Date: {{new_due_date}}
  \n- Extension Days: {{extension_days}}
  \n\nIf you have any questions, please contact the course staff.
  \n\nBest regards,
  \n{{course_name}} Staff".freeze

  # Approval and notification settings (formerly the "General Settings" tab).
  def approvals
    @course_settings = @course.course_settings || @course.build_course_settings
  end

  # Email subject/body templates (formerly the "Email Settings" tab).
  def emails
    @course_settings = @course.course_settings || @course.build_course_settings
  end

  def update
    @course_settings = @course.course_settings || @course.build_course_settings

    if params[:reset_email_template].present?
      reset_email_templates
      redirect_to emails_course_settings_path(@course), notice: 'Email templates reset to defaults.'
    elsif @course_settings.update(course_settings_params)
      redirect_to settings_redirect_path, notice: 'Course settings updated successfully.'
    else
      flash[:alert] = "Failed to update course settings: #{@course_settings.errors.full_messages.to_sentence}"
      redirect_to settings_redirect_path
    end
  end

  private

  # Redirects back to the settings page the form was submitted from.
  def settings_redirect_path
    params[:page] == 'emails' ? emails_course_settings_path(@course) : approvals_course_settings_path(@course)
  end

  def reset_email_templates
    @course_settings.update(
      email_subject: DEFAULT_EMAIL_SUBJECT,
      email_template: DEFAULT_EMAIL_TEMPLATE
    )
  end

  def course_settings_params
    params.require(:course_settings).permit(
      :auto_approve_days,
      :auto_approve_extended_request_days,
      :max_auto_approve,
      :enable_min_hours_before_deadline,
      :min_hours_before_deadline,
      :extend_late_due_date,
      :email_subject,
      :email_template
    )
  end

  def set_pending_request_count
    @pending_requests_count = Request.where(course_id: @course&.id, status: 'pending').count
  end
end
