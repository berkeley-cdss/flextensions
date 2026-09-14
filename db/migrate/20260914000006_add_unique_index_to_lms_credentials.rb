class AddUniqueIndexToLmsCredentials < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # One credential per user per LMS. Every lookup is by user then LMS, so the
  # unique index replaces the single-column user_id index. lms_id gets its own
  # index because it is a foreign key without one.
  def up
    safety_assured do
      # Among duplicates keep the most recently refreshed token.
      execute <<~SQL.squish
        DELETE FROM lms_credentials
        WHERE user_id IS NOT NULL AND lms_id IS NOT NULL
          AND id NOT IN (
            SELECT DISTINCT ON (user_id, lms_id) id
            FROM lms_credentials
            WHERE user_id IS NOT NULL AND lms_id IS NOT NULL
            ORDER BY user_id, lms_id, updated_at DESC, id DESC
          )
      SQL
    end

    add_index :lms_credentials, [ :user_id, :lms_id ], unique: true, algorithm: :concurrently
    add_index :lms_credentials, :lms_id, algorithm: :concurrently
    remove_index :lms_credentials, :user_id, algorithm: :concurrently
  end

  def down
    add_index :lms_credentials, :user_id, algorithm: :concurrently
    remove_index :lms_credentials, [ :user_id, :lms_id ], algorithm: :concurrently
    remove_index :lms_credentials, :lms_id, algorithm: :concurrently
  end
end
