# The single email template (email_subject / email_template) used to be sent
# for both approvals and denials. Those columns now hold the approval template
# and this pair holds the denial template. Existing rows are backfilled with the
# denial defaults so every course has a usable template the moment this ships.
class AddDenialEmailTemplatesToCourseSettings < ActiveRecord::Migration[8.1]
  # Copied from CourseSettings so the migration does not depend on the model
  # constants, which may change in later releases.
  DENIAL_SUBJECT = 'Extension Request Status: {{status}} - {{course_code}}'.freeze
  DENIAL_TEMPLATE = <<~TEMPLATE.freeze
    Hello {{student_name}},

    Your extension request for {{assignment_name}} in {{course_name}} ({{course_code}}) has been {{status}}.

    Request Details:
    - Original Due Date: {{original_due_date}}
    - Requested Due Date: {{requested_due_date}}
    - Days Requested: {{extension_days}}

    The original due date still applies. If you have any questions or would like to provide more information, please contact your course staff.

    Thanks,
    The {{course_name}} Team
  TEMPLATE

  def up
    add_column :course_settings, :denial_email_subject, :string
    add_column :course_settings, :denial_email_template, :text, default: ''

    # course_settings has one row per course, so a single-statement backfill
    # is small enough to run inline.
    safety_assured do
      execute <<~SQL
        UPDATE course_settings
        SET denial_email_subject = #{connection.quote(DENIAL_SUBJECT)},
            denial_email_template = #{connection.quote(DENIAL_TEMPLATE)}
      SQL
    end
  end

  def down
    remove_column :course_settings, :denial_email_template
    remove_column :course_settings, :denial_email_subject
  end
end
