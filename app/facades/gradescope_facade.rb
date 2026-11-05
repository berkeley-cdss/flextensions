class GradescopeFacade < LmsFacade
  class GradescopeAPIError < StandardError; end

  GRADESCOPE_URL = ENV.fetch('GRADESCOPE_URL', 'https://www.gradescope.com')

  def initialize(_token = nil)
    @api_token = nil # Gradescope does not support API tokens.
    @gradescope_conn = nil  # Wait until authenticated
  end

  # The Gradescope API Client does not operate with user tokens.
  # Instead, it uses a service account.
  # We maintain this method for compatibility with other facade instances.
  def self.from_user(_user = nil)
    new
  end

  def self.assignment_url(base_url, external_course_id, external_assignment_id)
    "#{base_url}/courses/#{external_course_id}/assignments/#{external_assignment_id}"
  end

  ### Review the Canvas Facade for methods which might need to be implemented here.
  # Add those methods to the base facade as well.

  ##
  # Gets all Gradescope assignments for a course.
  #
  # @param  [String] course_id the Gradescope course id to fetch assignments for.
  # @return [Array<Lmss::Gradescope::Assignment>] list of assignments in the course.
  def get_all_assignments(course_id)
    ensure_authenticated!
    begin
      # Get HTML content from Gradescope
      html = @gradescope_conn.get("/courses/#{course_id}/assignments")
      if html.blank?
        Rails.logger.error 'Failed to fetch assignments: No response'
        return []
      end

      # Extract React props containing assignment data from HTML
      props = @gradescope_conn.extract_react_props(html, 'AssignmentsTable')
      return [] unless props

      assignment_data = props['table_data'] || []
      assignment_data.map { |data| Lmss::Gradescope::Assignment.new(data) }
    rescue Lmss::Gradescope::AuthenticationError => e
      Rails.logger.error "Authentication failed: #{e.message}"
      raise e
    rescue => e
      Rails.logger.error "Failed to fetch Gradescope assignments: #{e.message}"
      Rails.error.report(e, handled: true,
                         context: { component: 'gradescope', operation: 'get_all_assignments', course_id: course_id })
      []
    end
  end

  ##
  # Gets a list of the assignment overrides for a specified assignment.
  #
  # @param   [String]    courseId     the course to fetch the overrides from.
  # @param   [String]    assignmentId the assignment to fetch the overrides from.
  # @return  [Array<Lmss::Gradescope::Override>] all of the overrides for the specified assignment.
  def get_assignment_overrides(course_id, assignment_id)
    ensure_authenticated!
    begin
      html = @gradescope_conn.get("/courses/#{course_id}/assignments/#{assignment_id}/extensions")
      if html.blank?
        Rails.logger.error 'Failed to fetch assignment extensions: No response'
        return []
      end

      # Extract React props containing overrides data from HTML
      overrides_data = @gradescope_conn.extract_all_react_props(html, 'EditExtension')
      return [] unless overrides_data

      overrides_data.map { |data| Lmss::Gradescope::Override.new(data) }
    rescue => e
      Rails.logger.error "Failed to fetch assignment extensions: #{e.message}"
      Rails.error.report(e, handled: true,
                         context: { component: 'gradescope', operation: 'get_assignment_overrides', course_id: course_id, assignment_id: assignment_id })
      []
    end
  end

  def get_existing_student_override(course_id, assignment_id, student_id)
    ensure_authenticated!
    overrides = get_assignment_overrides(course_id, assignment_id)
    overrides.find { |override| override.student_id == student_id }
  end

  ##
  # Provisions a new extension to a user.
  #
  # @param   [String] courseId the course to provision the extension in.
  # @param   [String] email of student to provision the extension for.
  # @param   [String] assignmentId the assignment the extension should be provisioned for.
  # @param   [String] newDueDate the date the assignment should be due.
  # @param   [String] newLateDueDate the late due date (optional, nil means no late due date set).
  # @return  [Lmss::Gradescope::BaseExtension] the extension that was provisioned.
  def provision_extension(course_id, student_email, assignment_id, new_due_date, new_late_due_date = nil)
    ensure_authenticated!
    begin
      # get extension page
      html = @gradescope_conn.get("/courses/#{course_id}/assignments/#{assignment_id}/extensions")
      if html.blank?
        Rails.logger.error 'Failed to fetch assignment extensions: No response'
        return nil
      end

      # Extract React props containing students data from HTML
      students_data = @gradescope_conn.extract_react_props(html, 'AddExtension')
      return nil unless students_data

      student_data = students_data['students'].find { |s| s['email'] == student_email }
      unless student_data
        Rails.logger.error "Failed to fetch assignment extensions: Student #{student_email} not found"
        return nil
      end
      student_id = student_data['id']

      # Build request payload
      request_payload = {
        'override' => {
          'user_id' => student_id,
          'settings' => {},
          'visible' => true
        }
      }

      if new_due_date
        request_payload['override']['settings']['due_date'] = {
          'type' => 'absolute',
          'value' => new_due_date
        }
        # Only set hard_due_date (late due date) if explicitly provided
        if new_late_due_date
          request_payload['override']['settings']['hard_due_date'] = {
            'type' => 'absolute',
            'value' => new_late_due_date
          }
        end
      end

      @gradescope_conn.post(
        "/courses/#{course_id}/assignments/#{assignment_id}/extensions", request_payload)

      # get id of created extension
      override = get_existing_student_override(course_id, assignment_id, student_id)
      unless override
        Rails.logger.error "Failed to verify extension creation for student #{student_email}"
        return nil
      end
      override
    rescue => e
      Rails.logger.error "Failed to provision extension: #{e.message}"
      raise e
    end
  end

  # See LmsFacade#student_identifier.
  def student_identifier(user)
    user.email
  end

  # See LmsFacade#extension_due_dates. Overrides identify students by their
  # Gradescope id, so these are matched to emails using the page's student list.
  def extension_due_dates(course_id, assignment_id)
    ensure_authenticated!
    html = extensions_page(course_id, assignment_id)
    emails = student_emails_by_id(html)

    extension_overrides(html).each_with_object({}) do |override, due_dates|
      email = emails[override.student_id.to_s]
      due_date = parse_extension_date(override.override_due_date)
      due_dates[email] = due_date if email && due_date
    end
  end

  # See LmsFacade#remove_extension. Reads the page again afterwards because a
  # rejected delete can still return a successful status.
  def remove_extension(course_id, student_email, assignment_id)
    ensure_authenticated!
    html = extensions_page(course_id, assignment_id)
    student_id = student_emails_by_id(html).key(student_email)
    override = find_extension_override(html, student_id)
    return false unless override

    @gradescope_conn.delete("/courses/#{course_id}/assignments/#{assignment_id}/extensions/#{override.id}")

    if find_extension_override(extensions_page(course_id, assignment_id), student_id)
      raise GradescopeAPIError, "Gradescope did not remove the extension for #{student_email}"
    end
    true
  end

  private

  # Unlike get_assignment_overrides, this raises on failure: callers must be
  # able to tell "no extensions" apart from "could not read the extensions".
  def extensions_page(course_id, assignment_id)
    html = @gradescope_conn.get("/courses/#{course_id}/assignments/#{assignment_id}/extensions")
    raise GradescopeAPIError, 'Failed to fetch assignment extensions: No response' if html.blank?

    html
  end

  def extension_overrides(html)
    @gradescope_conn.extract_all_react_props(html, 'EditExtension')
                    .map { |data| Lmss::Gradescope::Override.new(data) }
  end

  def find_extension_override(html, student_id)
    return if student_id.nil?

    extension_overrides(html).find { |override| override.student_id.to_s == student_id }
  end

  def student_emails_by_id(html)
    students = @gradescope_conn.extract_react_props(html, 'AddExtension')&.fetch('students', nil) || []
    students.to_h { |student| [ student['id'].to_s, student['email'] ] }
  end

  # An extension can hold a relative value rather than a date, which isn't one
  # Flextensions created, so anything unreadable is treated as having no date.
  def parse_extension_date(value)
    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  # Performs authentication to Gradescope if not already authenticated.
  def ensure_authenticated!
    return if @gradescope_conn

    @gradescope_conn = Lmss::Gradescope::Client.new(
      ENV.fetch('GRADESCOPE_EMAIL'),
      ENV.fetch('GRADESCOPE_PASSWORD'),
    )
    raise GradescopeAPIError, 'Failed to authenticate to Gradescope' unless @gradescope_conn
  end
end
