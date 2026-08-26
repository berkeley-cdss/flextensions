module Lmss
  module Pensive
    class Override < BaseOverride
      attr_reader :id, :student_id, :extension_days, :message

      def initialize(data, student_email:, extension_days:)
        @id = data['extension_id']
        @student_id = student_email
        @extension_days = extension_days
        @message = data['message']
      end

      def override_release_date = nil
      def override_due_date = nil
      def override_late_due_date = nil
    end
  end
end
