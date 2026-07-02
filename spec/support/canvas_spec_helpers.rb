# frozen_string_literal: true

require 'securerandom'
require 'active_support/core_ext/object/blank'

module CanvasSpecHelpers
  # Builds an Lmss::Canvas::Assignment from the top-level date fields, matching
  # what the facade receives from Canvas with override_assignment_dates=false.
  def build_canvas_assignment(attrs = {})
    defaults = {
      'id' => SecureRandom.uuid,
      'name' => 'Sample Assignment',
      'due_at' => '2025-01-15T23:59:00Z',
      'lock_at' => nil
    }

    assignment_data = defaults.merge(attrs.transform_keys(&:to_s))

    Lmss::Canvas::Assignment.new(assignment_data)
  end
end

RSpec.configure do |config|
  config.include(CanvasSpecHelpers)
end
