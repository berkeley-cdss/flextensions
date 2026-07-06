class CourseSettingsController < ApplicationController
  before_action :authenticated!
  before_action :authenticate_user
  before_action :set_course
  before_action :require_course_staff!
  before_action :set_pending_request_count
  before_action :set_course_settings

  def approvals
  end

  def emails
  end

  def update
    if params[:reset_email_template].present?
      reset_email_templates
      redirect_back_or_to emails_course_settings_path(@course), notice: 'Email templates reset to defaults.'
    elsif @course_settings.update(course_settings_params)
      redirect_back_or_to approvals_course_settings_path(@course), notice: 'Course settings updated successfully.'
    else
      flash[:alert] = "Failed to update course settings: #{@course_settings.errors.full_messages.to_sentence}"
      redirect_back_or_to approvals_course_settings_path(@course)
    end
  end

  private

  def set_course_settings
    @course_settings = @course.course_settings || @course.build_course_settings
  end

  def reset_email_templates
    @course_settings.update(
      email_subject: CourseSettings::DEFAULT_EMAIL_SUBJECT,
      email_template: CourseSettings::DEFAULT_EMAIL_TEMPLATE
    )
  end

  def course_settings_params
    params.expect(
      course_settings: [
        :enable_extensions,
        :auto_approve_days,
        :auto_approve_extended_request_days,
        :max_auto_approve,
        :enable_min_hours_before_deadline,
        :min_hours_before_deadline,
        :extend_late_due_date,
        :email_subject,
        :email_template
      ]
    )
  end
end
