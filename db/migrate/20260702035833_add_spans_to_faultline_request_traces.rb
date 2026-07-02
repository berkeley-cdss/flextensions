# frozen_string_literal: true

class AddSpansToFaultlineRequestTraces < ActiveRecord::Migration[7.2]
  def change
    # strong_migrations flags `json` columns and recommends `jsonb`. faultline
    # ships this as `json`; we keep that to match the gem's schema and assert
    # safety here rather than diverging. (Switch to `:jsonb` if preferred.)
    safety_assured do
      add_column :faultline_request_traces, :spans, :json
    end
    add_column :faultline_request_traces, :has_profile, :boolean, default: false
  end
end
