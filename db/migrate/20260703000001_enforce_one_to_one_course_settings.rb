class EnforceOneToOneCourseSettings < ActiveRecord::Migration[7.2]
  # Every course must have exactly one course_settings record. Courses created
  # going forward get one via an after_create callback; this migration fixes up
  # existing data and enforces the invariant at the database level.
  def up
    safety_assured do
      # Remove duplicate settings rows, keeping the oldest one per course.
      execute <<~SQL
        DELETE FROM course_settings
        WHERE id NOT IN (
          SELECT MIN(id) FROM course_settings GROUP BY course_id
        )
      SQL

      # Backfill settings (with column defaults) for courses that have none.
      execute <<~SQL
        INSERT INTO course_settings (course_id, created_at, updated_at)
        SELECT courses.id, NOW(), NOW()
        FROM courses
        LEFT JOIN course_settings ON course_settings.course_id = courses.id
        WHERE course_settings.id IS NULL
      SQL

      remove_index :course_settings, :course_id
      add_index :course_settings, :course_id, unique: true
    end
  end

  def down
    safety_assured do
      remove_index :course_settings, :course_id
      add_index :course_settings, :course_id
    end
  end
end
