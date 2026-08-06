# == Schema Information
#
# Table name: course_settings
#
#  id                                 :bigint           not null, primary key
#  auto_approve_days                  :integer          default(0)
#  auto_approve_extended_request_days :integer          default(0)
#  email_subject                      :string
#  email_template                     :text             default("")
#  enable_emails                      :boolean          default(FALSE)
#  enable_extensions                  :boolean          default(FALSE)
#  enable_gradescope                  :boolean          default(FALSE)
#  enable_min_hours_before_deadline   :boolean          default(TRUE), not null
#  enable_slack_webhook_url           :boolean
#  extend_late_due_date               :boolean          default(TRUE), not null
#  gradescope_course_url              :string
#  max_auto_approve                   :integer          default(0)
#  min_hours_before_deadline          :integer          default(0), not null
#  pending_notification_email         :string
#  pending_notification_frequency     :string
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
  DEFAULT_EMAIL_SUBJECT = 'Extension Request Status: {{status}} - {{course_code}}'.freeze
  DEFAULT_EMAIL_TEMPLATE = <<~TEMPLATE.freeze
    Hello {{student_name}},

    Your extension request for {{assignment_name}} in {{course_name}} ({{course_code}}) has been {{status}}.

    Extension Details:
    - Original Due Date: {{original_due_date}}
    - New Due Date: {{new_due_date}}
    - Extension Days: {{extension_days}}

    If you have any questions, please contact your course staff.

    Thanks,
    The {{course_name}} Team
  TEMPLATE

  # Each frequency needs a matching GoodJob cron entry in config/application.rb,
  # otherwise nothing ever enqueues the digest for courses that select it.
  VALID_NOTIFICATION_FREQUENCIES = %w[hourly daily weekly].freeze

  belongs_to :course
  validates :course_id, uniqueness: true

  # Empty <select> and blank <input> submissions become "" — coerce to nil so
  # `allow_nil` behaves as expected and unset rows compare equal.
  normalizes :pending_notification_frequency, :pending_notification_email, with: ->(v) { v.presence }

  before_save :ensure_system_user_for_auto_approval
  # Clear a stored email when notifications are turned off, so re-enabling
  # doesn't silently reuse a stale address.
  before_save -> { self.pending_notification_email = nil if pending_notification_frequency.nil? }
  # Seed the email templates on the row itself so the stored value is the
  # source of truth (the columns no longer carry a meaningful DB default).
  before_create :apply_default_email_templates

  validate :gradescope_url_is_valid, if: :enable_gradescope?
  validates :pending_notification_frequency, inclusion: { in: VALID_NOTIFICATION_FREQUENCIES }, allow_nil: true
  validates :pending_notification_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP },
                                         if: -> { pending_notification_frequency.present? }
  after_save :create_or_update_gradescope_link

  scope :with_pending_notifications, ->(frequency) {
    where(pending_notification_frequency: frequency)
    .where.not(pending_notification_email: nil)
  }

  def apply_default_email_templates
    self.email_subject = DEFAULT_EMAIL_SUBJECT if email_subject.blank?
    self.email_template = DEFAULT_EMAIL_TEMPLATE if email_template.blank?
  end

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
    return if gradescope_course_url&.match?(VALID_GRADESCOPE_URL)

    errors.add(:gradescope_course_url, 'must be a valid Gradescope course URL like https://gradescope.com/courses/123456')
  end

  def extract_gradescope_course_id(gradescope_course_url)
    match = gradescope_course_url&.match(%r{gradescope\.com/courses/(\d+)})
    match && match[1]
  end
end
