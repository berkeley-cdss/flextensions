class AddUniqueIndexToEnrollments < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # A user holds a given role in a course at most once. Roster sync relies on
  # this (insert_all skips rows that hit a unique index) and every role check
  # queries by user and course, so the unique index doubles as the lookup
  # index and makes the old single-column user_id index redundant.
  def up
    safety_assured do
      # Among duplicates keep the one carrying staff notes, then the one with
      # extended requests enabled, then the oldest.
      execute <<~SQL.squish
        DELETE FROM enrollments
        WHERE user_id IS NOT NULL AND course_id IS NOT NULL AND role IS NOT NULL
          AND id NOT IN (
            SELECT DISTINCT ON (user_id, course_id, role) id
            FROM enrollments
            WHERE user_id IS NOT NULL AND course_id IS NOT NULL AND role IS NOT NULL
            ORDER BY user_id, course_id, role,
                     (notes IS NOT NULL AND notes <> '') DESC,
                     allow_extended_requests DESC,
                     id
          )
      SQL
    end

    add_index :enrollments, [ :user_id, :course_id, :role ], unique: true, algorithm: :concurrently
    remove_index :enrollments, :user_id, algorithm: :concurrently
  end

  def down
    add_index :enrollments, :user_id, algorithm: :concurrently
    remove_index :enrollments, [ :user_id, :course_id, :role ], algorithm: :concurrently
  end
end
