class AddReasonTitleToFormSettings < ActiveRecord::Migration[7.2]
  # Instructor-supplied title for the always-required reason question. Left
  # nil the form falls back to FormSetting::DEFAULT_REASON_TITLE.
  def change
    add_column :form_settings, :reason_title, :string
  end
end
