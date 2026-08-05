class AddReleaseDateToAssignments < ActiveRecord::Migration[7.2]
  def change
    add_column :assignments, :release_date, :datetime
  end
end
