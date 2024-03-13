class CreateCoursesTable < ActiveRecord::Migration[7.1]
  def change
    create_table :courses_tables do |t|
      t.string 'course_name'
      t.timestamps
    end
  end
end
