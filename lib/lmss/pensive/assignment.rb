module Lmss
  module Pensive
    class Assignment < BaseAssignment
      attr_reader :id, :name, :release_date, :due_date, :late_due_date

      def initialize(data)
        @id = data['assignment_url'].presence || raise(ArgumentError, 'Pensive assignment URL is missing')
        @name = data['name'].presence || data['title'].presence || raise(ArgumentError, 'Pensive assignment name is missing')
        @release_date = parse_date(data['release_date'])
        @due_date = parse_date(data['due_date'])
        @late_due_date = parse_date(data['hard_due_date'] || data['late_due_date'])
      end

      private

      def parse_date(value)
        Time.zone.parse(value) if value.present?
      rescue ArgumentError
        raise ArgumentError, "Invalid Pensive assignment date: #{value}"
      end
    end
  end
end
