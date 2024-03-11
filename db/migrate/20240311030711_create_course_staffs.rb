class CreateCourseStaffs < ActiveRecord::Migration[7.1]
  def change
    create_table :course_staffs do |t|
      t.string 'email'

      t.timestamps
    end
  end
end
