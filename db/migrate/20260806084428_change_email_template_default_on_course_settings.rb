class ChangeEmailTemplateDefaultOnCourseSettings < ActiveRecord::Migration[8.1]
  def change
    change_column_default :course_settings, :email_template, from: nil, to: ""
  end
end
