class CreateCoursetolmss < ActiveRecord::Migration[7.1]
  def change
    create_table :coursetolmsses do |t|
      t.references :lms, foreign_key: true
      t.references :course, foreign_key: true

      t.timestamps
    end
  end
end
