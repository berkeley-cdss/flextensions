module Lmss
  module Canvas
    class Override < BaseOverride
      attr_reader :id, :title, :student_ids, :override_release_date,
                  :override_due_date, :override_late_due_date

      # @param data [OpenStruct] a decoded Canvas assignment override response.
      def initialize(data)
        @id = data.id
        @title = data.title
        @student_ids = data.student_ids
        @override_release_date = data.unlock_at
        @override_due_date = data.due_at
        @override_late_due_date = data.lock_at
      end
    end
  end
end
