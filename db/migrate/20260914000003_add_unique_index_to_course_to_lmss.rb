class AddUniqueIndexToCourseToLmss < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # A course links to each LMS at most once. The app assumed this everywhere
  # (Course#course_to_lms, the Gradescope link upsert) but only worked around
  # duplicates in Ruby. Collapse any duplicates, then enforce it at the
  # database level and index the (lms, external id) lookup that replaces the
  # old courses.canvas_id column.
  KEEP_ONE_PER_COURSE_AND_LMS = <<~SQL.squish.freeze
    SELECT DISTINCT ON (course_id, lms_id) id, course_id, lms_id
    FROM course_to_lmss
    WHERE course_id IS NOT NULL AND lms_id IS NOT NULL
    ORDER BY course_id, lms_id, (external_course_id IS NOT NULL) DESC, id
  SQL

  def up
    safety_assured do
      # Re-point assignments from duplicate links to the link being kept
      # (the oldest one that carries an external id) so the FK stays valid.
      execute <<~SQL.squish
        UPDATE assignments
        SET course_to_lms_id = keep.id
        FROM course_to_lmss dup
        JOIN (#{KEEP_ONE_PER_COURSE_AND_LMS}) keep
          ON keep.course_id = dup.course_id AND keep.lms_id = dup.lms_id
        WHERE assignments.course_to_lms_id = dup.id AND dup.id <> keep.id
      SQL

      execute <<~SQL.squish
        DELETE FROM course_to_lmss
        WHERE course_id IS NOT NULL AND lms_id IS NOT NULL
          AND id NOT IN (SELECT id FROM (#{KEEP_ONE_PER_COURSE_AND_LMS}) keep)
      SQL
    end

    add_index :course_to_lmss, [ :course_id, :lms_id ], unique: true, algorithm: :concurrently
    add_index :course_to_lmss, [ :lms_id, :external_course_id ], algorithm: :concurrently
    remove_index :course_to_lmss, :course_id, algorithm: :concurrently
    remove_index :course_to_lmss, :lms_id, algorithm: :concurrently
  end

  def down
    add_index :course_to_lmss, :course_id, algorithm: :concurrently
    add_index :course_to_lmss, :lms_id, algorithm: :concurrently
    remove_index :course_to_lmss, [ :course_id, :lms_id ], algorithm: :concurrently
    remove_index :course_to_lmss, [ :lms_id, :external_course_id ], algorithm: :concurrently
  end
end
