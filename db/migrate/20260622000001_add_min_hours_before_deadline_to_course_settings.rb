class AddMinHoursBeforeDeadlineToCourseSettings < ActiveRecord::Migration[7.2]
  def change
    # Adding a column with a default backfills all existing rows (courses) with
    # the default on Postgres 11+, so existing courses get "enabled" with 0 hours.
    safety_assured do
      change_table :course_settings, bulk: true do |t|
        t.boolean :enable_min_hours_before_deadline, default: true, null: false
        t.integer :min_hours_before_deadline, default: 0, null: false
      end
    end
  end
end
