require 'faraday'

require_relative 'error'

module Lmss
  module Pensieve
    ##
    # Thin JSON client for the Pensieve external-client API.
    #
    # Pensieve issues per-course-staff API tokens (see PENSIEVE_API_TOKEN); all
    # requests are authenticated with a Bearer token. The only endpoint Pensieve
    # has published so far is grant-extension, which is keyed by the assignment's
    # URL rather than a numeric id, so Pensieve "external assignment ids" are
    # assignment URLs throughout this integration.
    class Client
      BASE_URL = ENV.fetch('PENSIEVE_API_URL', 'https://api.pensieve.co')

      GRANT_EXTENSION_PATH = '/api/b2s/v1/external-client/grant-extension'.freeze
      # NOTE: Pensieve has not published an assignment-listing endpoint yet; this
      # path is our proposed shape and must be confirmed with Pensieve before
      # assignment sync can work. grant-extension (above) is extracted from the
      # legacy berkeley-cdss/extensions integration and is known to exist.
      LIST_ASSIGNMENTS_PATH = '/api/b2s/v1/external-client/assignments'.freeze

      def initialize(token)
        raise AuthenticationError, 'A Pensieve API token is required' if token.blank?

        @conn = Faraday.new(url: BASE_URL) do |f|
          f.request :json
          f.response :json
          f.headers['Authorization'] = "Bearer #{token}"
          f.adapter Faraday.default_adapter
        end
      end

      ##
      # Grants a student extra days on an assignment.
      #
      # @param [String]  assignment_url the Pensieve assignment URL.
      # @param [String]  student_email  the student's email in Pensieve.
      # @param [Integer] num_days       whole days to extend past the original deadline.
      # @return [Hash] the parsed response body.
      def grant_extension(assignment_url:, student_email:, num_days:)
        response = @conn.post(GRANT_EXTENSION_PATH, {
          assignment_url: assignment_url,
          student_email: student_email,
          num_days: num_days
        })
        data = handle_response(response)

        # Pensieve reports failures with a 200 + { success: false } body as well
        # as with HTTP errors, so both must be checked.
        unless data.is_a?(Hash) && data['success']
          raise RequestError, "Pensieve did not grant the extension: #{data.inspect.truncate(200)}"
        end

        data
      end

      ##
      # Lists the assignments of a Pensieve course.
      #
      # @param [String] course_url the Pensieve course URL.
      # @return [Array<Hash>] raw assignment hashes.
      def list_assignments(course_url)
        response = @conn.get(LIST_ASSIGNMENTS_PATH, { course_url: course_url })
        data = handle_response(response)
        return data if data.is_a?(Array)

        data.is_a?(Hash) ? Array(data['assignments']) : []
      end

      private

      def handle_response(response)
        case response.status
        when 200..299
          response.body
        when 401, 403
          raise AuthenticationError, 'Authentication to Pensieve failed'
        when 404
          raise NotFoundError, 'Pensieve resource not found'
        else
          raise RequestError, "Pensieve request failed: HTTP #{response.status}"
        end
      end
    end
  end
end
