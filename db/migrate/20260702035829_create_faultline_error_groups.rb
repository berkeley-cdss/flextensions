# frozen_string_literal: true

class CreateFaultlineErrorGroups < ActiveRecord::Migration[7.2]
  # Whole migration asserted safe: it creates a brand-new table and adds a
  # PostgreSQL generated `searchable` tsvector column via raw SQL. strong_migrations
  # cannot inspect execute() calls, and every operation here targets the table
  # created in this same migration, so there is nothing unsafe to guard against.
  def change
    safety_assured do
      create_table :faultline_error_groups do |t|
        t.string :fingerprint, null: false
        t.string :exception_class, null: false
        t.text :sanitized_message, null: false
        t.string :file_path
        t.integer :line_number
        t.string :method_name

        t.integer :occurrences_count, default: 0
        t.datetime :first_seen_at
        t.datetime :last_seen_at
        t.string :status, default: "unresolved"
        t.datetime :resolved_at
        t.datetime :last_notified_at

        t.timestamps
      end

      add_index :faultline_error_groups, :fingerprint, unique: true
      add_index :faultline_error_groups, :exception_class
      add_index :faultline_error_groups, :status
      add_index :faultline_error_groups, :last_seen_at

      # PostgreSQL: full-text search column with GIN index.
      if postgresql?
        execute <<-SQL.squish
          ALTER TABLE faultline_error_groups
          ADD COLUMN searchable tsvector
          GENERATED ALWAYS AS (
            to_tsvector('simple',
              coalesce(exception_class, '') || ' ' ||
              coalesce(sanitized_message, '') || ' ' ||
              coalesce(file_path, '')
            )
          ) STORED;
        SQL

        add_index :faultline_error_groups, :searchable, using: :gin
      end
    end
  end

  private

  def postgresql?
    ActiveRecord::Base.connection.adapter_name.downcase.include?("postgresql")
  end
end
