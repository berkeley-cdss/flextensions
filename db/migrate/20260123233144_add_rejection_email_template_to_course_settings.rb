class AddRejectionEmailTemplateToCourseSettings < ActiveRecord::Migration[7.2]
  def change
    add_column :course_settings, :rejection_email_subject, :string
    add_column :course_settings, :rejection_email_template, :text
  end
end
