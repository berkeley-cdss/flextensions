module Lmss
  module Pensieve
    ##
    # Pensieve's grant-extension response only acknowledges success (there is no
    # way to read an extension back), so this override carries what we sent plus
    # any id the response happens to include.
    class Override < BaseOverride
      attr_reader :id, :student_id, :override_due_date

      def initialize(data, student_email:, override_due_date:)
        @id = data.is_a?(Hash) ? (data['extension_id'] || data['id']) : nil
        @student_id = student_email
        @override_due_date = override_due_date
      end

      def override_release_date = nil
      def override_late_due_date = nil
    end
  end
end
