module Lmss
  module Canvas
    class Assignment < BaseAssignment
      attr_reader :id, :name, :due_date, :late_due_date

      def initialize(data)
        @id = data['id']
        @name = data['name']
        @due_date = extract_date_field(data, 'due_at')
        @late_due_date = extract_date_field(data, 'lock_at')
      end

      private

      def extract_date_field(assignment_data, field_name)
        base_date = assignment_data['base_date']
        if base_date
          # When base date info is available, trust it exclusively: a blank
          # value means there is no base date, not that the top-level value
          # (which may reflect an override's date) should be used instead.
          DateTime.parse(base_date[field_name]) if base_date[field_name].present?
        elsif assignment_data[field_name].present?
          DateTime.parse(assignment_data[field_name])
        end
      end
    end
  end
end
