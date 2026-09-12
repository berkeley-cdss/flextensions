class AddReasonTitleToFormSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :form_settings, :reason_title, :string
  end
end
