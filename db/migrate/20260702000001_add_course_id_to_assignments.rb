class AddCourseIdToAssignments < ActiveRecord::Migration[7.2]
  # The assignments table is small (bounded by a course's assignment count), so
  # the brief locks from adding the reference, FK, and NOT NULL are acceptable.
  def up
    safety_assured do
      # Denormalized FK so assignments can be looked up by course without joining
      # through course_to_lmss. Added nullable first so we can backfill existing rows.
      add_reference :assignments, :course, foreign_key: true, null: true

      # Backfill course_id from each assignment's existing course_to_lms link.
      execute <<~SQL.squish
        UPDATE assignments
        SET course_id = course_to_lmss.course_id
        FROM course_to_lmss
        WHERE assignments.course_to_lms_id = course_to_lmss.id
      SQL

      # Every assignment belongs to a course, mirroring course_to_lms_id.
      change_column_null :assignments, :course_id, false
    end
  end

  def down
    remove_reference :assignments, :course, foreign_key: true
  end
end
