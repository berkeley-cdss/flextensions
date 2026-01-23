class AddRejectionEmailTemplateToCourseSettings < ActiveRecord::Migration[7.2]
  def change
    add_column :course_settings, :rejection_email_subject, :string,
               default: "Extension Request Status: {{status}} - {{course_code}}"
    # Note: This default template should match CourseSettings::DEFAULT_REJECTION_EMAIL_TEMPLATE
    # but we cannot reference the constant in migrations due to class loading order
    add_column :course_settings, :rejection_email_template, :text,
               default: <<~TEMPLATE.squish
                 Hello {{student_name}},

                 Your extension request for {{assignment_name}} in {{course_name}} ({{course_code}}) has been {{status}}.

                 Reason for rejection: {{feedback_message}}

                 If you have any questions, please reach out to your course staff.

                 Thank you,
                 {{course_name}} Staff
               TEMPLATE
  end
end
