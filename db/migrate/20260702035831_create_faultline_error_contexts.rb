# frozen_string_literal: true

class CreateFaultlineErrorContexts < ActiveRecord::Migration[7.2]
  def change
    create_table :faultline_error_contexts do |t|
      t.references :error_occurrence, null: false, foreign_key: { to_table: :faultline_error_occurrences }
      t.string :key, null: false
      t.text :value

      t.timestamps
    end

    add_index :faultline_error_contexts, [ :error_occurrence_id, :key ]
  end
end
