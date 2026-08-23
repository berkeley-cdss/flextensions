class EnforceOneToOneCourseSettings < ActiveRecord::Migration[7.2]
  # Every course must have exactly one course_settings record. Courses created
  # going forward get one via an after_create callback; this migration fixes up
  # existing data and enforces the invariant at the database level.
  #
  # Like RenameUserToCoursesToEnrollments, this shipped under two version
  # numbers -- 20260702000001 (84fc0909) and 20260703000001 -- so a database
  # that applied the first sees this one as pending and runs it a second time.
  # The two backfill statements are already idempotent; the index swap is what
  # needs guarding, since re-running it drops a live unique constraint just to
  # recreate it.
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

      unless connection.index_exists?(:course_settings, :course_id, unique: true)
        remove_index :course_settings, :course_id
        add_index :course_settings, :course_id, unique: true
      end
    end
  end

  def down
    safety_assured do
      remove_index :course_settings, :course_id
      add_index :course_settings, :course_id
    end
  end
end
