class AddNotesToEnrollments < ActiveRecord::Migration[7.2]
  def change
    add_column :enrollments, :notes, :text
  end
end
