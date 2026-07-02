module Lmss
  module Canvas
    class Assignment < BaseAssignment
      attr_reader :id, :name, :due_date, :late_due_date, :base_date

      def initialize(data)
        @id = data['id']
        @name = data['name']
        @base_date = data['base_date']
        @due_date = extract_date_field(data, 'due_at')
        @late_due_date = extract_date_field(data, 'lock_at')
      end

      def base_date_present?
        @base_date.is_a?(Hash) && @base_date.any?
      end

      private

      # The facade fetches assignments with override_assignment_dates=false, so
      # the top-level due_at/lock_at are the assignment's base ("Everyone") dates
      # for any number of overrides. See docs/Canvas_Dates_API.md.
      def extract_date_field(assignment_data, field_name)
        DateTime.parse(assignment_data[field_name]) if assignment_data[field_name].present?
      end
    end
  end
end
