class RenameUserToCoursesToEnrollments < ActiveRecord::Migration[7.2]
  def change
    safety_assured { rename_table :user_to_courses, :enrollments }
  end
end
