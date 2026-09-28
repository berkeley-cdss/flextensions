class AddDemoCourseToCourses < ActiveRecord::Migration[7.2]
  def change
    # demo_course flags sandbox/demo courses (e.g. the developer-login test
    # course). It only helps us track usage so these can be excluded from real
    # metrics; it has no effect on application behavior.
    add_column :courses, :demo_course, :boolean, default: false, null: false
  end
end
