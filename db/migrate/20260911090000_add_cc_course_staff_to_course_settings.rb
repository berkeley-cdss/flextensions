# When enabled, every email sent to a student (submission confirmation,
# approval, denial) is also CC'd to the course reply address so staff keep a
# copy of every notification.
class AddCcCourseStaffToCourseSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :course_settings, :cc_course_staff, :boolean, default: false, null: false
  end
end
