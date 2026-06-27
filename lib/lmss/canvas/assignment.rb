module Lmss
  module Canvas
    class Assignment < BaseAssignment
      attr_reader :id, :name, :due_date, :late_due_date, :overrides_count

      def initialize(data)
        @id = data['id']
        @name = data['name']
        @due_date = extract_date_field(data, 'due_at')
        @late_due_date = extract_date_field(data, 'lock_at')
        @base_date_present = data['base_date'].present?
        @overrides_count = Array(data['overrides']).size
      end

      # Whether Canvas returned an explicit base (non-override) date for this
      # assignment. Canvas omits the `all_dates` array (the source of the base
      # date) once an assignment has more than ~25 dates, in which case the
      # due/late dates fall back to the root-level fields, which Canvas may
      # populate from an override and therefore report as too late.
      def base_date?
        @base_date_present
      end

      private

      def extract_date_field(assignment_data, field_name)
        if assignment_data['base_date'] && assignment_data['base_date'][field_name].present?
          DateTime.parse(assignment_data['base_date'][field_name])
        elsif assignment_data[field_name].present?
          DateTime.parse(assignment_data[field_name])
        end
      end
    end
  end
end
