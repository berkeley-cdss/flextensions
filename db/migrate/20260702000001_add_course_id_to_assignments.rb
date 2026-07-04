class AddCourseIdToAssignments < ActiveRecord::Migration[7.2]
  # Assignments were only reachable from a course through course_to_lmss,
  # so every course-scoped assignment query paid for a join. Denormalizing
  # course_id onto assignments lets those queries hit an indexed FK directly.
  def up
    safety_assured do
      add_reference :assignments, :course, foreign_key: true, index: true

      # Backfill from the existing join table. course_to_lms_id is NOT NULL and
      # CourseToLms requires a course, so this covers every row.
      execute <<~SQL.squish
        UPDATE assignments
        SET course_id = course_to_lmss.course_id
        FROM course_to_lmss
        WHERE assignments.course_to_lms_id = course_to_lmss.id
      SQL

      change_column_null :assignments, :course_id, false
    end
  end

  def down
    remove_reference :assignments, :course, foreign_key: true
  end
end
