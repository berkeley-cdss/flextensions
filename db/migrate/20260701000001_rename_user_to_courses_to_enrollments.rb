class RenameUserToCoursesToEnrollments < ActiveRecord::Migration[7.2]
  def change
    # The table is small, so renaming it is safe.
    # rename_table also renames the primary key sequence and the
    # index_user_to_courses_on_* indexes to match the new table name.
    safety_assured do
      rename_table :user_to_courses, :enrollments
    end
  end
end
