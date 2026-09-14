# The single email template (email_subject / email_template) used to be sent
# for both approvals and denials. Those columns now hold the approval template
# and this pair holds the denial template. Both stay NULL until course staff
# customize them; CourseSettings#email_templates_for falls back to the default
# text, so improvements to the defaults reach every course that has not edited
# them.
class AddDenialEmailTemplatesToCourseSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :course_settings, :denial_email_subject, :string
    add_column :course_settings, :denial_email_template, :text
  end
end
