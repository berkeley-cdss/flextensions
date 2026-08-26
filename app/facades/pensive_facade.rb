class PensiveFacade < LmsFacade
  class PensiveAPIError < LmsFacade::LmsAPIError; end

  API_URL = ENV.fetch('PENSIEVE_API_URL', 'https://api.pensieve.co')
  GRANT_EXTENSION_PATH = '/api/b2s/v1/external-client/grant-extension'

  def initialize(token = nil, conn = nil)
    @email = ENV['PENSIEVE_EMAIL']
    @api_token = token.presence || ENV['PENSIEVE_API_TOKEN']
    raise PensiveAPIError, 'PENSIEVE_EMAIL must be set to use Pensive' if @email.blank?
    raise PensiveAPIError, 'PENSIEVE_API_TOKEN must be set to use Pensive' if @api_token.blank?

    @pensive_conn = conn || Faraday.new(
      url: API_URL,
      headers: {
        'Authorization' => "Bearer #{@api_token}",
        'Content-Type' => 'application/json'
      },
      request: { timeout: 30 }
    )
  end

  # Pensive uses an integration account rather than the acting user's token.
  def self.from_user(_user = nil)
    new
  end

  # Pensive identifies assignments by URL. Assignment sync therefore stores
  # the URL as external_assignment_id, making this normally an identity method.
  def self.assignment_url(base_url, external_course_id, external_assignment_id)
    return external_assignment_id if external_assignment_id.to_s.match?(%r{\Ahttps?://})

    "#{base_url.to_s.chomp('/')}/teacher/classes/#{external_course_id}/my-assignments/#{external_assignment_id}"
  end

  # The legacy Pensive API only exposes grant-extension. PENSIEVE_ASSIGNMENTS_PATH
  # supplies the assignment-list endpoint separately so the rest of the
  # Flextensions assignment-sync pipeline can stay LMS-agnostic.
  #
  # Expected response:
  #   { "success": true, "assignments": [
  #       { "assignment_url": "https://...", "name": "Homework 1",
  #         "release_date": "...", "due_date": "...", "hard_due_date": "..." }
  #   ] }
  def get_all_assignments(course_id)
    path = ENV['PENSIEVE_ASSIGNMENTS_PATH'].presence
    unless path
      raise PensiveAPIError,
            'PENSIEVE_ASSIGNMENTS_PATH must be set to a Pensive assignment-list API endpoint'
    end

    response = request(:get, path, { class_id: course_id })
    data = parse_success_response(response, operation: 'fetch assignments')
    assignments = data['assignments']
    raise PensiveAPIError, 'Pensive assignment response did not contain an assignments array' unless assignments.is_a?(Array)

    assignments.map { |assignment| Lmss::Pensive::Assignment.new(assignment) }
  rescue ArgumentError => e
    raise PensiveAPIError, "Pensive returned an invalid assignment: #{e.message}"
  end

  def get_assignment_overrides(_course_id, _assignment_id)
    raise PensiveAPIError, 'Pensive does not expose an API for listing assignment extensions'
  end

  # Pensive's API differs from date-based LMS APIs: it accepts a whole-day
  # extension instead of an absolute due date. The caller supplies both forms
  # so this method remains compatible with LmsFacade#provision_extension.
  def provision_extension(_course_id, student_email, assignment_url, _new_due_date,
                          _new_late_due_date = nil, extension_days:)
    unless assignment_url.to_s.match?(%r{\Ahttps?://})
      raise PensiveAPIError, 'Pensive assignment URL must be an absolute HTTP(S) URL'
    end

    days = Integer(extension_days)
    raise PensiveAPIError, 'Pensive extension days must be positive' unless days.positive?

    response = request(
      :post,
      GRANT_EXTENSION_PATH,
      {
        assignment_url: assignment_url,
        student_email: student_email,
        num_days: days
      }
    )
    data = parse_success_response(response, operation: 'grant extension')
    Lmss::Pensive::Override.new(data, student_email: student_email, extension_days: days)
  rescue ArgumentError, TypeError
    raise PensiveAPIError, 'Pensive extension days must be a positive integer'
  end

  private

  def request(method, path, payload)
    case method
    when :get
      @pensive_conn.get(path, payload)
    when :post
      @pensive_conn.post(path) { |request| request.body = payload.to_json }
    else
      raise ArgumentError, "Unsupported HTTP method: #{method}"
    end
  rescue Faraday::Error => e
    raise PensiveAPIError, "Pensive request failed: #{e.message}"
  end

  def parse_success_response(response, operation:)
    unless response.status.between?(200, 299)
      raise PensiveAPIError,
            "Pensive could not #{operation} (HTTP #{response.status}): #{truncate(response.body)}"
    end

    data = JSON.parse(response.body)
    unless data.is_a?(Hash) && data['success'] == true
      raise PensiveAPIError, "Pensive could not #{operation}: #{truncate(data.inspect)}"
    end

    data
  rescue JSON::ParserError
    raise PensiveAPIError, "Pensive returned invalid JSON while attempting to #{operation}"
  end

  def truncate(value)
    value.to_s.truncate(500)
  end
end
