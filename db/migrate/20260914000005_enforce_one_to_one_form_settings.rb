class EnforceOneToOneFormSettings < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # form_settings is one-to-one with courses (has_one), like course_settings,
  # but only carried a plain index. Keep the oldest row per course, which is
  # the one has_one would have returned, then make the index unique.
  def up
    safety_assured do
      execute <<~SQL.squish
        DELETE FROM form_settings
        WHERE id NOT IN (SELECT MIN(id) FROM form_settings GROUP BY course_id)
      SQL
    end

    remove_index :form_settings, :course_id, algorithm: :concurrently
    add_index :form_settings, :course_id, unique: true, algorithm: :concurrently
  end

  def down
    remove_index :form_settings, :course_id, algorithm: :concurrently
    add_index :form_settings, :course_id, algorithm: :concurrently
  end
end
