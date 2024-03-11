class CreateCourseStaffsTable < ActiveRecord::Migration[7.1]
  def change
    create_table :course_staffs_tables do |t|
      t.string 'email'
      t.timestamps
    end
  end
end
