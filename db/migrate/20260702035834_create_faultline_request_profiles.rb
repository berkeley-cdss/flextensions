# frozen_string_literal: true

class CreateFaultlineRequestProfiles < ActiveRecord::Migration[7.2]
  def change
    create_table :faultline_request_profiles do |t|
      t.references :request_trace, null: false, foreign_key: { to_table: :faultline_request_traces, on_delete: :cascade }
      t.text :profile_data, null: false
      t.string :mode, default: 'cpu'
      t.integer :samples, default: 0
      t.float :interval_ms

      t.datetime :created_at, null: false
    end
  end
end
