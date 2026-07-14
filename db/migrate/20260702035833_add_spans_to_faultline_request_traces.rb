# frozen_string_literal: true

class AddSpansToFaultlineRequestTraces < ActiveRecord::Migration[7.2]
  # Whole migration asserted safe. strong_migrations flags `add_column … :json`
  # (it prefers `jsonb`); faultline ships this column as `:json`, and we keep the
  # gem's schema rather than diverging. Both column adds are safe on PostgreSQL 11+.
  def change
    safety_assured do
      add_column :faultline_request_traces, :spans, :json
      add_column :faultline_request_traces, :has_profile, :boolean, default: false
    end
  end
end
