class CreateExtensions < ActiveRecord::Migration[7.1]
  def change
    create_table :extensions do |t|
      t.string :student_email
      t.datetime :initial_due_date
      t.datetime :new_due_date
      t.uuid :last_processed_by_user_id
      # By Ruby convention, the following line of code creates a field called 'assignment_id' tp extensions table,
      # and this 'assignment_id' is a foreign key referring to the primary key of the assignment that this extension belongs to.
      # The assignment_id field is removed from the assignments table.
      t.references :assignment, type: :uuid, foreign_key: true

      t.timestamps
    end
  end
end
