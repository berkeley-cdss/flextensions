class RemoveEmailSubjectDefaultOnCourseSettings < ActiveRecord::Migration[8.1]
  def change
    change_column_default :course_settings, :email_subject,
                          from: 'Extension Request Status: {{status}} - {{course_code}}', to: nil
  end
end
