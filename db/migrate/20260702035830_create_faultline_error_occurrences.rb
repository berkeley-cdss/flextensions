# frozen_string_literal: true

class CreateFaultlineErrorOccurrences < ActiveRecord::Migration[7.2]
  def change
    create_table :faultline_error_occurrences do |t|
      t.references :error_group, null: false, foreign_key: { to_table: :faultline_error_groups }

      t.string :exception_class, null: false
      t.text :message, null: false
      t.text :backtrace

      t.string :request_method
      t.string :request_url
      t.text :request_params
      t.text :request_headers
      t.string :user_agent
      t.string :ip_address

      t.bigint :user_id
      t.string :user_type
      t.string :session_id

      t.string :environment
      t.string :hostname
      t.string :process_id

      t.json :local_variables

      t.timestamps
    end

    add_index :faultline_error_occurrences, :created_at
    add_index :faultline_error_occurrences, [ :error_group_id, :created_at ]
    add_index :faultline_error_occurrences, [ :user_type, :user_id ]
  end
end
