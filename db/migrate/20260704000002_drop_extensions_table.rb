class DropExtensionsTable < ActiveRecord::Migration[7.2]
  def up
    drop_table :extensions
  end

  def down
    create_table :extensions do |t|
      t.bigint :assignment_id
      t.string :student_email
      t.datetime :initial_due_date
      t.datetime :new_due_date
      t.bigint :last_processed_by_id
      t.string :external_extension_id
      t.timestamps

      t.index [:assignment_id], name: 'index_extensions_on_assignment_id'
      t.index [:last_processed_by_id], name: 'index_extensions_on_last_processed_by_id'
    end

    add_foreign_key :extensions, :assignments
    add_foreign_key :extensions, :users, column: :last_processed_by_id
  end
end
