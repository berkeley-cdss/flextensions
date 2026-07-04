# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: course_settings
#
#  id                                 :bigint           not null, primary key
#  auto_approve_days                  :integer          default(0)
#  auto_approve_extended_request_days :integer          default(0)
#  email_subject                      :string           default("Extension Request Status: {{status}} - {{course_code}}")
#  email_template                     :text             default("Dear {{student_name}},\n\nYour extension request for {{assignment_name}} in {{course_name}} ({{course_code}}) has been {{status}}.\n\nExtension Details:\n- Original Due Date: {{original_due_date}}\n- New Due Date: {{new_due_date}}\n- Extension Days: {{extension_days}}\n\nIf you have any questions, please contact the course staff.\n\nBest regards,\n{{course_name}} Staff")
#  enable_emails                      :boolean          default(FALSE)
#  enable_extensions                  :boolean          default(FALSE)
#  enable_gradescope                  :boolean          default(FALSE)
#  enable_min_hours_before_deadline   :boolean          default(TRUE), not null
#  enable_slack_webhook_url           :boolean
#  extend_late_due_date               :boolean          default(TRUE), not null
#  gradescope_course_url              :string
#  max_auto_approve                   :integer          default(0)
#  min_hours_before_deadline          :integer          default(0), not null
#  reply_email                        :string
#  slack_webhook_url                  :string
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  course_id                          :bigint           not null
#
# Indexes
#
#  index_course_settings_on_course_id  (course_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (course_id => courses.id)
#
# rubocop:enable Layout/LineLength

class CourseSettings < ApplicationRecord
  # TODO: Remove the db default text, and use an AR validation.
  DEFAULT_EMAIL_SUBJECT = 'Extension Request Status: {{status}} - {{course_code}}'.freeze
  DEFAULT_EMAIL_TEMPLATE = <<~TEMPLATE.freeze
    Dear {{student_name}},

    Your extension request for {{assignment_name}} in {{course_name}} ({{course_code}}) has been {{status}}.

    Extension Details:
    - Original Due Date: {{original_due_date}}
    - New Due Date: {{new_due_date}}
    - Extension Days: {{extension_days}}

    If you have any questions, please contact the course staff.

    Best regards,
    {{course_name}} Staff
  TEMPLATE

  belongs_to :course

  # Courses and settings are 1:1; the course_id unique index enforces this at
  # the database level.
  validates :course_id, uniqueness: true

  before_save :ensure_system_user_for_auto_approval
  validate :gradescope_url_is_valid, if: :enable_gradescope?
  after_save :create_or_update_gradescope_link

  def automatic_approval_enabled?
    return false unless enable_extensions?

    auto_approve_days.positive? || auto_approve_extended_request_days.positive?
  end

  # True when this save just turned on the Slack webhook, so callers know to
  # send a confirmation ping.
  def slack_webhook_just_enabled?
    enable_slack_webhook_url && slack_webhook_url.present? && saved_change_to_slack_webhook_url?
  end

  def slack_enabled_message
    ":wave: Slack notifications have been enabled for *#{course.course_name}* " \
      "(#{course.course_code}). You will now receive updates here!"
  end

  def ensure_system_user_for_auto_approval
    # Create the system user if auto-approval is being enabled
    return unless enable_extensions && auto_approve_days.to_i.positive?

    SystemUserService.ensure_auto_approval_user_exists
  end

  VALID_GRADESCOPE_URL = %r{\Ahttps://(www\.)?gradescope\.com/courses/\d+/?\z}

  # TODO: if disabled should unsync Gradescope assignments
  def create_or_update_gradescope_link
    return unless enable_gradescope

    gradescope_course_id = extract_gradescope_course_id(gradescope_course_url)
    CourseToLms.find_or_initialize_by(course_id: course.id, lms_id: GRADESCOPE_LMS_ID).tap do |course_to_lms|
      course_to_lms.external_course_id = gradescope_course_id
      course_to_lms.save!
    end
  end

  def gradescope_url_is_valid
    return if gradescope_course_url.match?(VALID_GRADESCOPE_URL)

    errors.add(:gradescope_course_url, 'must be a valid Gradescope course URL like https://gradescope.com/courses/123456')
  end

  def extract_gradescope_course_id(gradescope_course_url)
    match = gradescope_course_url.match(%r{gradescope\.com/courses/(\d+)})
    match[1]
  end
end
