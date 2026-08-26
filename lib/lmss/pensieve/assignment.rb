module Lmss
  module Pensieve
    class Assignment < BaseAssignment
      attr_reader :id, :name, :release_date, :due_date, :late_due_date

      def initialize(data)
        # Pensieve's grant-extension endpoint is keyed by assignment URL, so the
        # URL is the external assignment id.
        @id = data['url'] || data['assignment_url']
        @name = data['name'] || data['title']
        @release_date = data['release_date']
        @due_date = data['due_date']
        @late_due_date = data['late_due_date']
      end
    end
  end
end
