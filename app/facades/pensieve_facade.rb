##
# Facade for the Pensieve assignment platform (https://www.pensieve.co).
#
# Extracted from the legacy berkeley-cdss/extensions integration. Pensieve's
# external-client API differs from the other LMSs in two important ways:
#
# 1. Assignments are identified by their Pensieve URL, not a numeric id, so
#    `external_assignment_id` holds the assignment URL and
#    `external_course_id` holds the course URL.
# 2. Extensions are granted as a number of whole days past the original
#    deadline (`num_days`), not as an absolute date, so provisioning converts
#    the requested due date into days relative to the assignment's due date.
#    The time-of-day of the requested due date cannot be sent to Pensieve, and
#    Pensieve has no concept of a separate late due date.
class PensieveFacade < LmsFacade
  class PensieveAPIError < StandardError; end

  PENSIEVE_URL = ENV.fetch('PENSIEVE_URL', 'https://www.pensieve.co')

  def initialize(_token = nil)
    @pensieve_conn = nil # Wait until first use to read credentials.
  end

  # Pensieve uses a course-wide service token (PENSIEVE_API_TOKEN) rather than
  # per-user tokens. We maintain this method for compatibility with other
  # facade instances.
  def self.from_user(_user = nil)
    new
  end

  # Pensieve external assignment ids are already full assignment URLs, so no
  # URL needs to be assembled.
  def self.assignment_url(_base_url, _external_course_id, external_assignment_id)
    external_assignment_id
  end

  ##
  # Gets all Pensieve assignments for a course.
  #
  # NOTE: this depends on an assignment-listing endpoint Pensieve has not
  # published yet (see Lmss::Pensieve::Client::LIST_ASSIGNMENTS_PATH). Until
  # Pensieve confirms it, this returns [] (which SyncAllCourseAssignmentsJob
  # treats as a no-op rather than disabling existing assignments).
  #
  # @param  [String] course_id the Pensieve course URL to fetch assignments for.
  # @return [Array<Lmss::Pensieve::Assignment>] list of assignments in the course.
  def get_all_assignments(course_id)
    ensure_authenticated!
    begin
      @pensieve_conn.list_assignments(course_id).map { |data| Lmss::Pensieve::Assignment.new(data) }
    rescue Lmss::Pensieve::AuthenticationError => e
      Rails.logger.error "Pensieve authentication failed: #{e.message}"
      raise e
    rescue => e
      Rails.logger.error "Failed to fetch Pensieve assignments: #{e.message}"
      Rails.error.report(e, handled: true,
                         context: { component: 'pensieve', operation: 'get_all_assignments', course_id: course_id })
      []
    end
  end

  # Pensieve's API cannot read extensions back, only grant them.
  def get_assignment_overrides(_course_id, _assignment_id)
    []
  end

  ##
  # Provisions a new extension to a user.
  #
  # @param   [String] course_id the Pensieve course URL to provision the extension in.
  # @param   [String] student_email email of the student to provision the extension for.
  # @param   [String] assignment_id the Pensieve assignment URL to extend.
  # @param   [String] new_due_date the date the assignment should be due.
  # @param   [String] _new_late_due_date ignored; Pensieve has no late due date.
  # @return  [Lmss::Pensieve::Override, nil] the extension that was provisioned.
  def provision_extension(course_id, student_email, assignment_id, new_due_date, _new_late_due_date = nil)
    ensure_authenticated!

    num_days = extension_days(course_id, assignment_id, new_due_date)
    return nil if num_days.nil?

    begin
      data = @pensieve_conn.grant_extension(
        assignment_url: assignment_id,
        student_email: student_email,
        num_days: num_days
      )
      Lmss::Pensieve::Override.new(data, student_email: student_email, override_due_date: new_due_date)
    rescue => e
      Rails.logger.error "Failed to provision Pensieve extension: #{e.message}"
      raise e
    end
  end

  private

  ##
  # Converts an absolute requested due date into the whole number of days past
  # the assignment's original deadline, which is the only form Pensieve accepts.
  # Returns nil (and logs) when the assignment or its due date is unknown or the
  # requested date grants no additional days.
  def extension_days(course_id, assignment_id, new_due_date)
    assignment = Assignment.joins(:course_to_lms)
                           .where(course_to_lmss: { lms_id: PENSIEVE_LMS_ID, external_course_id: course_id })
                           .find_by(external_assignment_id: assignment_id)
    if assignment.nil? || assignment.due_date.nil?
      Rails.logger.error "Cannot extend Pensieve assignment #{assignment_id}: no synced assignment with a due date"
      return nil
    end

    num_days = (Time.zone.parse(new_due_date.to_s).to_date - assignment.due_date.to_date).to_i
    if num_days < 1
      Rails.logger.error "Cannot extend Pensieve assignment #{assignment_id}: requested due date #{new_due_date} grants no additional days"
      return nil
    end

    num_days
  end

  # Builds the API client on first use so credentials are only required when
  # Pensieve is actually used.
  def ensure_authenticated!
    return if @pensieve_conn

    @pensieve_conn = Lmss::Pensieve::Client.new(ENV.fetch('PENSIEVE_API_TOKEN'))
  rescue KeyError, Lmss::Pensieve::AuthenticationError
    raise PensieveAPIError, 'PENSIEVE_API_TOKEN must be set to use Pensieve'
  end
end
