# The approval email subject/body used to be copied onto every course_settings
# row, so improvements to the default text never reached existing courses.
# They now work like the denial columns: NULL unless course staff customized
# them, with CourseSettings#email_templates_for falling back to the current
# default. This migration drops the "" column default and clears every stored
# approval template that still matches one of the defaults it was seeded with.
#
# The default body has been reworded a few times, so every past version is
# listed here. Templates are compared ignoring CRLF line endings, surrounding
# whitespace, and the {{extension_days}} -> {{requested_days}} rename, so a
# course that once clicked "Reset to Default" is treated as not customized.
# Customized templates are left untouched: {{extension_days}} keeps working as
# an alias of {{requested_days}}.
class ResetDefaultApprovalEmailTemplates < ActiveRecord::Migration[8.1]
  class MigrationCourseSettings < ActiveRecord::Base
    self.table_name = 'course_settings'
  end

  DEFAULT_SUBJECT = 'Extension Request Status: {{status}} - {{course_code}}'

  DETAILS = <<~TEXT.freeze
    Your extension request for {{assignment_name}} in {{course_name}} ({{course_code}}) has been {{status}}.

    Extension Details:
    - Original Due Date: {{original_due_date}}
    - New Due Date: {{new_due_date}}
    - Extension Days: {{requested_days}}
  TEXT

  # Newest first. The first entry is the default at the time of this migration
  # and is what `down` seeds back onto rows left NULL.
  DEFAULT_BODIES = [
    <<~TEXT,
      Hello {{student_name}},

      #{DETAILS}
      The new due date has been applied to the assignment. If you have any questions, please contact your course staff.

      Thanks,
      The {{course_name}} Team
    TEXT
    <<~TEXT,
      Hello {{student_name}},

      #{DETAILS}
      If you have any questions, please contact your course staff.

      Thanks,
      The {{course_name}} Team
    TEXT
    <<~TEXT,
      Dear {{student_name}},

      #{DETAILS}
      If you have any questions, please contact the course staff.

      Best regards,
      {{course_name}} Staff
    TEXT
    <<~TEXT
      Hello {{student_name}},

      #{DETAILS}
      If you have any questions, please reach out to your course staff.

      Thank you,
      {{course_name}} Staff
    TEXT
  ].freeze

  def up
    change_column_default :course_settings, :email_template, from: '', to: nil

    default_bodies = DEFAULT_BODIES.map { |body| normalize(body) }

    # The bare table class above has no validations or callbacks to skip.
    MigrationCourseSettings.reset_column_information
    MigrationCourseSettings.find_each do |settings|
      updates = {}
      updates[:email_subject] = nil if uses_default?(settings.email_subject, [ normalize(DEFAULT_SUBJECT) ])
      updates[:email_template] = nil if uses_default?(settings.email_template, default_bodies)
      settings.update_columns(updates) if updates.any? # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def down
    MigrationCourseSettings.reset_column_information
    # rubocop:disable Rails/SkipsModelValidations
    MigrationCourseSettings.where(email_subject: [ nil, '' ]).update_all(email_subject: DEFAULT_SUBJECT)
    MigrationCourseSettings.where(email_template: [ nil, '' ]).update_all(email_template: DEFAULT_BODIES.first)
    # rubocop:enable Rails/SkipsModelValidations

    change_column_default :course_settings, :email_template, from: nil, to: ''
  end

  private

  def uses_default?(value, normalized_defaults)
    value.blank? || normalized_defaults.include?(normalize(value))
  end

  def normalize(text)
    text.gsub("\r\n", "\n").gsub('{{extension_days}}', '{{requested_days}}').strip
  end
end
