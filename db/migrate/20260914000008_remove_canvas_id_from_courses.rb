class RemoveCanvasIdFromCourses < ActiveRecord::Migration[8.1]
  # courses.canvas_id duplicated course_to_lmss.external_course_id for the
  # Canvas link, and Course#canvas_id already read from the link. Copy any
  # value that only lives on the column into the link, then drop the column
  # so course_to_lmss is the single source of truth for external course ids.
  def up
    safety_assured do
      execute <<~SQL.squish
        UPDATE course_to_lmss
        SET external_course_id = courses.canvas_id
        FROM courses
        WHERE course_to_lmss.course_id = courses.id
          AND course_to_lmss.lms_id = #{CANVAS_LMS_ID}
          AND course_to_lmss.external_course_id IS NULL
          AND courses.canvas_id IS NOT NULL
      SQL

      execute <<~SQL.squish
        INSERT INTO course_to_lmss (course_id, lms_id, external_course_id, created_at, updated_at)
        SELECT courses.id, #{CANVAS_LMS_ID}, courses.canvas_id, NOW(), NOW()
        FROM courses
        WHERE courses.canvas_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1 FROM course_to_lmss
            WHERE course_to_lmss.course_id = courses.id AND course_to_lmss.lms_id = #{CANVAS_LMS_ID}
          )
      SQL

      remove_column :courses, :canvas_id
    end
  end

  def down
    add_column :courses, :canvas_id, :string
    add_index :courses, :canvas_id, unique: true

    execute <<~SQL.squish
      UPDATE courses
      SET canvas_id = course_to_lmss.external_course_id
      FROM course_to_lmss
      WHERE course_to_lmss.course_id = courses.id AND course_to_lmss.lms_id = #{CANVAS_LMS_ID}
    SQL
  end
end
