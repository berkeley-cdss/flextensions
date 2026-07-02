# frozen_string_literal: true

class ChangeSanitizedMessageToText < ActiveRecord::Migration[7.2]
  # OVERRIDE (Rails 7.2 / vendored-faultline install):
  #
  # On a fresh install this migration is a no-op AND impossible to run on
  # PostgreSQL. The initial CreateFaultlineErrorGroups migration already creates
  # `sanitized_message` as :text and adds a generated `searchable` tsvector
  # column derived from it. Postgres then refuses to alter the column's type:
  #   PG::FeatureNotSupported: cannot alter type of a column used by a
  #   generated column ("sanitized_message" is used by generated column
  #   "searchable").
  # This migration only exists upstream to upgrade legacy installs that created
  # the column as :string before the generated column was introduced. We guard
  # it so it is skipped whenever the column is already the target type.
  def up
    return if column_exists?(:faultline_error_groups, :sanitized_message, :text)

    safety_assured do
      change_column :faultline_error_groups, :sanitized_message, :text, null: false
    end
  end

  def down
    return if column_exists?(:faultline_error_groups, :sanitized_message, :string)

    safety_assured do
      change_column :faultline_error_groups, :sanitized_message, :string, null: false
    end
  end
end
