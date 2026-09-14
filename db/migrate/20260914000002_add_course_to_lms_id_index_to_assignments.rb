class AddCourseToLmsIdIndexToAssignments < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # course_to_lms_id is a foreign key that the assignment sync job and the
  # bulk enable/disable action query directly, but only the denormalized
  # course_id was indexed.
  def change
    add_index :assignments, :course_to_lms_id, algorithm: :concurrently
  end
end
