class AddPensieveToCourseSettings < ActiveRecord::Migration[8.1]
  def change
    # Adding a column with a default backfills all existing rows (courses) with
    # the default on Postgres 11+, so existing courses get Pensieve disabled.
    safety_assured do
      change_table :course_settings, bulk: true do |t|
        t.boolean :enable_pensieve, default: false, null: false
        t.string :pensieve_course_url
      end
    end
  end
end
