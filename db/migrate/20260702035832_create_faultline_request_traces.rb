# frozen_string_literal: true

class CreateFaultlineRequestTraces < ActiveRecord::Migration[7.2]
  def change
    create_table :faultline_request_traces do |t|
      t.string  :endpoint,        null: false
      t.string  :http_method,     null: false
      t.string  :path
      t.integer :status
      t.float   :duration_ms
      t.float   :db_runtime_ms
      t.float   :view_runtime_ms
      t.integer :db_query_count,  default: 0

      t.datetime :created_at,     null: false
    end

    add_index :faultline_request_traces, :endpoint
    add_index :faultline_request_traces, :created_at
    add_index :faultline_request_traces, [ :endpoint, :created_at ]
  end
end
