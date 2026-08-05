require 'date'
require 'cgi'
require 'faraday'
require 'json'
require 'ostruct'

# This is the facade for Canvas.
class CanvasFacade < LmsFacade
  class CanvasAPIError < LmsFacade::LmsAPIError; end

  CANVAS_URL = ENV.fetch('CANVAS_URL', nil)
  CANVAS_CUSTOM_COURSE_ROLES = {
    Enrollment::LEAD_TA_ROLE => 'Lead TA'
  }.freeze

  # Canvas instances can scope the flextensions developer key.
  # There must be one scope for each endpoint we can use.
  # This may not exceed 8000 characters in length, typically ~110 total scopes.
  # Pass these to the `scope` parameter of the `canvas_authorize_url` method.
  # This list must exactly match the scopes enabled for the Canvas developer key.
  # https://ucberkeleysandbox.instructure.com/accounts/1/developer_keys#api_key_modal_opened
  # Verify the scope which are on a key easily by querying the Canvas API:
  # curl -X GET \
  #   -H "Authorization: Bearer <your_access_token>" \
  #   "https://ucberkeleysandbox.instructure.com/api/v1/accounts/1/developer_keys/
  # NOTE: When using omniauth-canvas, the following scope is **required**:
  # url:GET|/api/v1/users/:user_id/profile
  # Without this, Canvas returns a horribly opaque error about invalid scopes, even if they match.
  #
  # Whenever a new scope is added, it must be added to the Canvas developer key **FIRST**,
  # especially in the production environment. You will likely want to use feature flags
  # and coordination with Berkeley to ensure that the scopes are added to the developer key.
  # NOTE: Changing the key's scopes invalidates EVERY token already derived from the key.
  # Run `bin/rails lms_credentials:purge` afterwards to drop the dead stored credentials;
  # users re-authenticate automatically on their next visit. (Any dead credential that is
  # not purged is also removed automatically the first time its refresh fails with
  # invalid_grant -- see LmsCredential#refresh!.)
  # NOTE: This is read into the OmniAuth initializer in `config/initializers/omniauth.rb`.
  # If you change this list, you will need to restart the Rails server.
  CANVAS_API_SCOPES = [
    # Scopes are sorted by the order in which they appear on the API Key edit modal.
    # Assignments
    'url:GET|/api/v1/courses/:course_id/assignments/:assignment_id/overrides',
    'url:POST|/api/v1/courses/:course_id/assignments/:assignment_id/overrides',
    'url:GET|/api/v1/courses/:course_id/assignments/overrides',
    'url:POST|/api/v1/courses/:course_id/assignments/overrides',
    'url:GET|/api/v1/courses/:course_id/assignments/:assignment_id/overrides/:id',
    'url:PUT|/api/v1/courses/:course_id/assignments/:assignment_id/overrides/:id',
    'url:DELETE|/api/v1/courses/:course_id/assignments/:assignment_id/overrides/:id',
    # Assignments - Bulk Operations
    'url:GET|/api/v1/courses/:course_id/assignments',
    'url:PUT|/api/v1/courses/:course_id/assignments/overrides',
    'url:POST|/api/v1/courses/:course_id/assignments/overrides',
    # Assignment Date Extension Details
    'url:GET|/api/v1/courses/:course_id/assignments/:assignment_id/date_details',
    'url:GET|/api/v1/courses/:course_id/quizzes/:quiz_id/date_details',
    # Assignments - Basic Info
    'url:GET|/api/v1/courses/:course_id/assignments',
    'url:GET|/api/v1/courses/:course_id/assignments/:id',
    'url:GET|/api/v1/courses/:course_id/assignments/:assignment_id/users/:user_id/group_members',
    # Courses
    # Note: /courses is scoped to the current user.
    'url:GET|/api/v1/courses',
    'url:GET|/api/v1/courses/:id',
    'url:GET|/api/v1/courses/:course_id/users',
    # Quiz Assignment Overrides
    'url:GET|/api/v1/courses/:course_id/quizzes/assignment_overrides',
    'url:GET|/api/v1/courses/:course_id/new_quizzes/assignment_overrides',
    # Users
    'url:GET|/api/v1/users/:user_id/profile',
    'url:GET|/api/v1/users/:id'
  ].join(' ')

  # Potential future scopes:
  # Assignment extensions, for addtional attempts
  # url:GET|/api/v1/users/:user_id/enrollments
  # url:GET|/api/v1/courses/:course_id/enrollments
  # For PL integration
  # url:GET|/api/v1/courses/:course_id/quizzes/:quiz_id/ip_filters
  # url:POST|/api/v1/courses/:course_id/assignments/:assignment_id/extensions
  # url:GET|/api/v1/sections/:course_section_id/assignments/:assignment_id/override
  # url:POST|/api/v1/courses/:course_id/quizzes/:quiz_id/extensions
  # url:GET|/api/v1/courses/:id/late_policy
  # url:POST|/api/v1/courses/:id/late_policy
  # url:PATCH|/api/v1/courses/:id/late_policy

  def auth_header
    { Authorization: "Bearer #{@api_token}" }
  end

  ##
  # Configures the facade with the canvas api endpoint configured in the environment.
  #
  # @param [String]              masqueradeToken the token of the user to masquerade as.
  # @param [Faraday::Connection] existing connection to use (defaults to nil).
  # Enable this to automatically parse JSON responses.
  # This will require some refactoring (and rebuilding VCRs/webmock)
  # do |faraday|
  #     faraday.request :url_encoded # passed first, only affects request parameters.
  #     faraday.request :json # 2nd, only affects request body
  #     faraday.response :json, content_type: /\bjson$/
  #     faraday.adapter Faraday.default_adapter
  # end
  def initialize(token, conn = nil)
    @api_token = token
    @canvas_conn = conn || Faraday.new(
      url: "#{CanvasFacade::CANVAS_URL}/api/v1",
      headers: auth_header
    )
  end

  def self.from_user(user)
    token = user.canvas_credentials&.token
    raise CanvasAPIError, 'Cannot find Canvas token for user' if token.nil?

    new(token)
  end

  # See LmsFacade.assignment_url.
  def self.assignment_url(base_url, external_course_id, external_assignment_id)
    "#{base_url}/courses/#{external_course_id}/assignments/#{external_assignment_id}"
  end

  # rubocop:disable Layout/LineLength
  # Depaginate a Canvas API response
  # call as: CanvasFacade.depaginate_response(response)
  # See https://canvas.instructure.com/doc/api/file.pagination
  # Example Header response:
  # link: <https://bcourses.berkeley.edu/api/v1/courses?page=1&per_page=10>; rel="current",<https://bcourses.berkeley.edu/api/v1/courses?page=2&per_page=10>; rel="next",<https://bcourses.berkeley.edu/api/v1/courses?page=1&per_page=10>; rel="first",<https://bcourses.berkeley.edu/api/v1/courses?page=11&per_page=10>; rel="last"
  # rubocop:enable Layout/LineLength

  HEADER_LINK_PARTS = /<(?<url>.*)>;\s+rel="(?<rel>.*)"/
  # TODO: This really needs tests
  # Because this is an instance method, it's a little awkward to use:
  # facade = CanvasFacade.new(token)
  # all_courses = facade.depaginate_response(facade.get_all_courses)
  def depaginate_response(response)
    return response unless response.success?

    links = response.headers['Link']
    return JSON.parse(response.body) unless links

    links = links.split(',').map(&:strip).filter_map do |link|
      match = link.match(HEADER_LINK_PARTS)
      { url: match[:url], rel: match[:rel] } if match
    end

    # Canvas provides a 'next' page as long as there is more to query
    next_page = links.find { |page| page[:rel] == 'next' }
    return JSON.parse(response.body) if next_page.nil?

    # NOTE: Do not log the full :url as it may contain tokens (from canvas)
    # The connection's default headers already carry the Authorization header;
    # passing them again here would append them to the URL as query params.
    rest = depaginate_response(@canvas_conn.get(next_page[:url]))
    raise CanvasAPIError, 'Failed to fetch a paginated Canvas response' unless rest.is_a?(Array)

    JSON.parse(response.body) + rest
  end

  ##
  # Gets all courses for the authorized user.
  #
  # @return [Array<Hash>] list of the Course (hashes) the user has access to.
  def get_all_courses
    depaginate_response(@canvas_conn.get('courses', {
      per_page: 100,
      'include[]': 'term'
    }))
  end

  ##
  # Get all enrollments for a course.
  #
  # https://ucberkeleysandbox.instructure.com/doc/api/courses.html#method.courses.users
  # @param  [Course] A Course object.
  # @param  [String|Array<String>] role the role to filter users by (optional).
  # @return [Array<Hash>] list of the Enrollment (hashes) in the course.
  def get_all_course_users(course, role = nil)
    # sigh, manually construct query string until we tweak Faraday middleware
    # to include :url_encoded, then use `'enrollment_type[]' : list_or_string`
    query_string = 'per_page=100'
    query_string += "&#{role_query_param(role)}" if role.is_a?(String) && role.present?

    if role.is_a?(Array) && role.present? # rubocop:disable Style/IfUnlessModifier
      query_string += role.map { |r| "&#{role_query_param(r)}" }.join
    end

    depaginate_response(@canvas_conn.get("courses/#{course.canvas_id}/users?#{query_string}"))
  end

  ##
  # Get all courses for which the user is an instructor.
  # Makes 2 API calls to Canvas, one for `teacher` and one for `ta`.
  #
  # @return [Faraday::Response] list of the courses the user is an instructor for.
  def get_instructor_courses
    teacher_courses = @canvas_conn.get('courses', {
      enrollment_type: 'teacher',
      per_page: 100,
      'include[]': 'term'
    })
    ta_courses = @canvas_conn.get('courses', {
      enrollment_type: 'ta',
      per_page: 100,
      'include[]': 'term'
    })
    # TODO: Remove duplication of courses with multiple roles (e.g. teacher + ta)
    teacher_courses + ta_courses
  end

  def role_query_param(role)
    normalized_role = Enrollment.normalize_role(role)
    canvas_course_role = CANVAS_CUSTOM_COURSE_ROLES[normalized_role]

    if canvas_course_role
      "enrollment_role=#{CGI.escape(canvas_course_role)}"
    else
      "enrollment_type[]=#{CGI.escape(normalized_role)}"
    end
  end

  ##
  # Gets a specified course that the authorized user has access to.
  #
  # @param  [Integer] courseId the course id to look up.
  # @return [Faraday::Response] information about the requested course.
  def get_course(courseId)
    @canvas_conn.get("courses/#{courseId}", { 'include[]': 'term' })
  end

  ##
  # Gets assignments for a course (single page).
  #
  # We pass override_assignment_dates=false so the top-level due_at/unlock_at/
  # lock_at are the assignment's base ("Everyone") dates rather than the dates
  # overridden for the calling user. Canvas guarantees these top-level dates are
  # the base dates for any number of overrides, so we do NOT need include[]=
  # all_dates (which is truncated past 25 dates anyway). See docs/Canvas_Dates_API.md.
  #
  # @param  [String] course_id the Canvas course id to fetch assignments for.
  # @return [Faraday::Response] single page of assignments in the course.
  def get_assignments(course_id)
    @canvas_conn.get("courses/#{course_id}/assignments", {
      'override_assignment_dates' => false,
      'per_page' => 100
    })
  end

  ##
  # Gets all Canvas assignments for a course (paginated).
  #
  # @param  [String] course_id the Canvas course id to fetch assignments for.
  # @return [Array<Lmss::Canvas::Assignment>] list of assignments in the course.
  def get_all_assignments(course_id)
    depaginate_response(get_assignments(course_id)).map do |assignment_data|
      Lmss::Canvas::Assignment.new(assignment_data)
    end
  end

  ##
  # Gets a specified assignment from a course, with its base ("Everyone") dates
  # at the top level (override_assignment_dates=false). See docs/Canvas_Dates_API.md.
  #
  # @param  [Integer] course_id     the course to fetch the assignment from.
  # @param  [Integer] assignment_id the id of the assignment to fetch.
  # @return [Faraday::Response] information about the requested assignment.
  def get_assignment(course_id, assignment_id)
    @canvas_conn.get("courses/#{course_id}/assignments/#{assignment_id}", {
      'override_assignment_dates' => false
    })
  end

  ##
  # Fetches the base ("Everyone"/all students) dates for an assignment.
  #
  # Reads the top-level due_at/unlock_at/lock_at from the assignment endpoint
  # with override_assignment_dates=false, which Canvas guarantees to be the base
  # dates for any number of overrides. The /date_details endpoint is NOT needed
  # for this -- it exposes no base date key and its top-level dates are the same
  # base dates. See docs/Canvas_Dates_API.md.
  #
  # @param  [Integer] course_id     the course the assignment belongs to.
  # @param  [Integer] assignment_id the assignment to fetch the base dates for.
  # @return [Hash, nil] { 'due_at', 'unlock_at', 'lock_at' }, or nil if the
  #                     dates could not be fetched.
  def get_base_dates(course_id, assignment_id)
    response = get_assignment(course_id, assignment_id)
    return nil unless response.success?

    JSON.parse(response.body).slice('due_at', 'unlock_at', 'lock_at')
  rescue JSON::ParserError
    nil
  end

  ##
  # Gets a single page of the assignment overrides for a specified assignment.
  #
  # @param   [Integer]    courseId     the course to fetch the overrides from.
  # @param   [Integer]    assignmentId the assignment to fetch the overrides from.
  # @return  [Faraday::Response] the first page of overrides for the specified assignment.
  def get_assignment_overrides(courseId, assignmentId)
    @canvas_conn.get("courses/#{courseId}/assignments/#{assignmentId}/overrides", { per_page: 100 })
  end

  ##
  # Gets all of the assignment overrides for a specified assignment (depaginated).
  # An assignment can have arbitrarily many overrides, so callers that need to
  # find a specific override must use this rather than a single page.
  #
  # @param   [Integer] course_id     the course to fetch the overrides from.
  # @param   [Integer] assignment_id the assignment to fetch the overrides from.
  # @return  [Array<Hash>|Faraday::Response] all overrides, or the raw response on failure.
  def get_all_assignment_overrides(course_id, assignment_id)
    depaginate_response(get_assignment_overrides(course_id, assignment_id))
  end

  ##
  # Creates a new assignment override.
  #
  # @param   [Integer]    courseId     the id of the course to create the override for.
  # @param   [Integer]    assignmentId the id of the assignment to create the override for.
  # @param   [Enumerable] studentIds   the student ids to provision the override to.
  # @param   [String]     title        the title of the new override.
  # @param   [String]     dueDate      the new due date for the override.
  # @param   [String]     unlockDate   the date the override should unlock the assignment.
  # @param   [String]     lockDate     the date the override should lock the assignment.
  # @return  [Faraday::Response] information about the new override.
  # TODO: Rename this to create_assignment_extenstion. Title should be optional.
  def create_assignment_override(courseId, assignmentId, studentIds, title, dueDate, unlockDate, lockDate)
    @canvas_conn.post("courses/#{courseId}/assignments/#{assignmentId}/overrides", {
      assignment_override: {
        student_ids: studentIds,
        title: title,
        due_at: dueDate,
        unlock_at: unlockDate,
        lock_at: lockDate
      }
    })
  end

  ##
  # Updates an existing assignment override.
  #
  # @param   [Integer]    courseId     the id of the course to update the override for.
  # @param   [Integer]    assignmentId the id of the assignment to update the override for.
  # @param   [Enumerable] studentIds   the updated student ids to provision the override to.
  # @param   [String]     title        the updated title of the override.
  # @param   [String]     dueDate      the updated due date for the override.
  # @param   [String]     unlockDate   the updated date the override should unlock the assignment.
  # @param   [String]     lockDate     the updated date the override should lock the assignment.
  # @return  [Faraday::Response] information about the updated override.
  def update_assignment_override(courseId, assignmentId, overrideId, studentIds, title, dueDate, unlockDate, lockDate)
    # NOTE: Canvas requires the params be nested under assignment_override,
    # just like the create endpoint; un-nested params are silently ignored.
    @canvas_conn.put("courses/#{courseId}/assignments/#{assignmentId}/overrides/#{overrideId}", {
      assignment_override: {
        student_ids: studentIds,
        title: title,
        due_at: dueDate,
        unlock_at: unlockDate,
        lock_at: lockDate
      }
    })
  end

  ##
  # Deletes an assignment override.
  #
  # @param  [Integer] courseId the id of the course where the override to delete is provisioned.
  # @param  [Integer] assignmentId the assignment for which the override to delete is provisioned.
  # @param  [Integer] overrideId the id of the override to delete.
  # @return [Faraday::Response] information about the deleted override.
  def delete_assignment_override(courseId, assignmentId, overrideId)
    @canvas_conn.delete("courses/#{courseId}/assignments/#{assignmentId}/overrides/#{overrideId}")
  end

  ##
  # Provisions a new extension to a user.
  #
  # Overrides are titled "N day(s) extension" (computed from the base due
  # date) so that all students with the same length extension share a group:
  # if an override with the matching title and dates already exists, the
  # student is added to it rather than getting their own override. Keeping
  # students grouped also keeps the total override count down, which matters
  # because Canvas stops reporting reliable assignment dates once an
  # assignment has more than 25 overrides.
  #
  # If the student already has an override:
  # - and it is already the matching group, nothing is changed.
  # - and they are the only student on it, it is updated (and renamed, e.g.
  #   "1 day extension" -> "2 days extension") in place, or deleted in favor
  #   of joining an existing matching group.
  # - and it is shared with other students, the student is removed from it --
  #   keeping its title and dates intact for the remaining students -- and
  #   then added to the matching group or given a new override.
  #
  # @param   [Integer] course_id the course to provision the extension in.
  # @param   [Integer] student_id the student to provision the extension for.
  # @param   [Integer] assignment_id the assignment the extension should be provisioned for.
  # @param   [String]  new_due_date the date the assignment should be due.
  # @param   [String]  new_close_date the close date for submissions (optional, nil means no close date set).
  # @return  [Lmss::Canvas::Override] the override that acts as the extension.
  # @raises  [FailedPipelineError] if a Canvas response body could not be parsed.
  # @raises  [NotFoundError]       if the user has an existing override that cannot be located.
  # @raises  [CanvasAPIError]      if Canvas rejected the extension.
  def provision_extension(course_id, student_id, assignment_id, new_due_date, new_close_date = nil)
    override_title = extension_override_title(course_id, assignment_id, new_due_date)
    recovering = false

    loop do
      # Search *all* overrides (depaginated), since an assignment may have
      # well over a page of overrides.
      overrides = list_override_structs(course_id, assignment_id)
      student_override = find_student_override(overrides, student_id)
      raise NotFoundError, 'could not find student\'s override' if recovering && student_override.nil?

      group_override = find_group_override(overrides, override_title, new_due_date, new_close_date)

      # The student is already in the matching group: nothing to post.
      if student_override && group_override && student_override.id == group_override.id
        return Lmss::Canvas::Override.new(student_override)
      end

      response = move_student_to_extension_override(
        course_id, student_id, assignment_id, student_override, group_override,
        override_title, new_due_date, new_close_date
      )
      decoded_response = parse_create_response(response)

      # Canvas reports 'taken' when the student already belongs to an
      # override, e.g. one created between our lookup above and the write;
      # re-fetch the overrides and retry once.
      if !recovering && response.status == 400 && override_taken_error?(decoded_response)
        recovering = true
        next
      end

      unless (200..299).cover?(response.status)
        raise CanvasAPIError, "Canvas could not save the extension (HTTP #{response.status})"
      end

      return Lmss::Canvas::Override.new(decoded_response)
    end
  end

  private

  ##
  # Fetches every override for an assignment as OpenStructs.
  #
  # @param  [Integer] course_id the course to fetch the overrides from.
  # @param  [Integer] assignment_id the assignment to fetch the overrides from.
  # @return [Array<OpenStruct>] all of the assignment's overrides.
  # @throws [FailedPipelineError] if the overrides could not be fetched or parsed.
  def list_override_structs(course_id, assignment_id)
    begin
      # Depaginate: with many overrides (e.g. > 25) the override we're looking
      # for may not be on the first page, and missing it would orphan it.
      all_assignment_overrides = get_all_assignment_overrides(course_id, assignment_id)
    rescue JSON::ParserError
      raise FailedPipelineError.new(
        'Update Student Extension',
        'Get Existing Student Override',
        'Parse Canvas Response'
      )
    end

    # depaginate_response returns the raw response when the request failed.
    unless all_assignment_overrides.is_a?(Array)
      raise FailedPipelineError.new(
        'Update Student Extension',
        'Get Existing Student Override',
        'Fetch Assignment Overrides'
      )
    end

    all_assignment_overrides.map { |override_data| OpenStruct.new(override_data) }
  end

  ##
  # Finds the override the student currently belongs to, if any.
  #
  # @param  [Array<OpenStruct>] overrides the assignment's overrides.
  # @param  [Integer] student_id the student to look for.
  # @return [OpenStruct|nil] the override if it is found or nil if not.
  def find_student_override(overrides, student_id)
    overrides.find { |override| override.student_ids&.map(&:to_i)&.include?(student_id.to_i) }
  end

  ##
  # Finds an existing extension group override that the student could join:
  # an adhoc (student list) override with the same title, due date, and
  # close date.
  #
  # @param  [Array<OpenStruct>] overrides the assignment's overrides.
  # @param  [String] title the extension group title (e.g. "1 day extension").
  # @param  [String] due_date the extension due date.
  # @param  [String] close_date the extension close date (may be nil).
  # @return [OpenStruct|nil] the matching group override, or nil if none.
  def find_group_override(overrides, title, due_date, close_date)
    overrides.find do |override|
      override.student_ids.present? &&
        override.title == title &&
        same_canvas_time?(override.due_at, due_date) &&
        same_canvas_time?(override.lock_at, close_date)
    end
  end

  ##
  # Gets the existing override for a student.
  #
  # @param  [Integer] course_id the courseId to check for an existing override.
  # @param  [Integer] student_id the student to check for an existing override for.
  # @param  [Integer] assignment_id the assignment to check for an existing override for.
  # @return [OpenStruct|nil] the override if it is found or nil if not.
  # @throws [FailedPipelineError] if the existing overrides response body could not be parsed.
  def get_existing_student_override(course_id, student_id, assignment_id)
    find_student_override(list_override_structs(course_id, assignment_id), student_id)
  end

  ##
  # Computes the title for an extension override: "N day(s) extension",
  # so that all students with the same length extension share a title and
  # can be grouped into one override.
  #
  # Uses the explicitly-queried base due date (the assignment's own due_at
  # cannot be trusted once it has many overrides). Falls back to
  # "Extended to <date>" when the number of days cannot be determined.
  #
  # @param  [Integer] course_id the course the assignment belongs to.
  # @param  [Integer] assignment_id the assignment being extended.
  # @param  [String]  new_due_date the new due date for the extension.
  # @return [String] the override title.
  def extension_override_title(course_id, assignment_id, new_due_date)
    base_due_date = get_base_dates(course_id, assignment_id)&.fetch('due_at', nil)
    days = extension_days(base_due_date, new_due_date)
    return "Extended to #{new_due_date}" if days.nil? || days < 1

    days == 1 ? '1 day extension' : "#{days} days extension"
  end

  ##
  # Computes the length of an extension in days, rounded to the nearest day.
  #
  # @param  [String] base_due_date the assignment's base due date.
  # @param  [String] new_due_date the extension's due date.
  # @return [Integer|nil] the number of days, or nil if it cannot be computed.
  def extension_days(base_due_date, new_due_date)
    return nil if base_due_date.blank? || new_due_date.blank?

    ((Time.zone.parse(new_due_date.to_s) - Time.zone.parse(base_due_date.to_s)) / 1.day).round
  rescue ArgumentError
    nil
  end

  ##
  # Compares two Canvas timestamps for equality, tolerating different
  # formats/zones (e.g. "2025-01-16T23:59:00-08:00" vs "2025-01-17T07:59:00Z").
  #
  # @param  [String] time_a the first timestamp (may be nil).
  # @param  [String] time_b the second timestamp (may be nil).
  # @return [Boolean] true if both are blank or both represent the same time.
  def same_canvas_time?(time_a, time_b)
    return time_a.blank? && time_b.blank? if time_a.blank? || time_b.blank?

    Time.zone.parse(time_a.to_s) == Time.zone.parse(time_b.to_s)
  rescue ArgumentError
    false
  end

  ##
  # Gets the current time as formatted for Canvas's version of iso8601.
  #
  # @return [String] the current time that Canvas likes.
  def get_current_formatted_time
    currDateTimeUnformatted = DateTime.now.utc.iso8601
    # This is some weird format of iso8601 standard that Canvas likes... Don't ask me.
    "#{/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}/.match(currDateTimeUnformatted)[0]}Z"
  end

  ##
  # Removes a student from an existing override.
  #
  # @param   [Integer]    courseId the courseId to remove the student from the override of.
  # @param   [OpenStruct] override the existing override to remove the student from.
  # @param   [Integer]    studentId the id of the student to remove from the override.
  # @return  [Faraday::Response] the new override if successful.
  # @raises  [FailedPipelineError] if the student could not be removed from the override.
  def remove_student_from_override(courseId, override, studentId)
    # Keep the override's title and dates untouched so the remaining students
    # are unaffected (e.g. a shared "1 day extension" override keeps its name).
    remaining_student_ids = override.student_ids.reject { |id| id.to_i == studentId.to_i }
    res = update_assignment_override(
      courseId,
      override.assignment_id,
      override.id,
      remaining_student_ids,
      override.title,
      override.due_at,
      override.unlock_at,
      override.lock_at
    )
    decodedBody = begin
      JSON.parse(res.body, object_class: OpenStruct)
    rescue JSON::ParserError
      nil
    end
    if !(200..299).cover?(res.status) || decodedBody&.student_ids&.map(&:to_i)&.include?(studentId.to_i)
      raise FailedPipelineError.new(
        'Update Student Extension',
        'Remove Student from Existing Override',
        'Could not remove student'
      )
    end
    res
  end

  ##
  # Parses the response from creating an assignment override.
  #
  # @param  [Faraday::Response] response the response to parse.
  # @return [OpenStruct] the parsed response.
  # @raises [FailedPipelineError] if the response body could not be parsed.
  def parse_create_response(response)
    JSON.parse(response.body, object_class: OpenStruct)
  rescue JSON::ParserError
    raise FailedPipelineError.new('Update Student Extension', 'Parse Creation Response')
  end

  ##
  # Checks whether a 400 response failed solely because the student already
  # belongs to another override ('taken'), in which case we can recover by
  # locating and updating the existing override.
  #
  # @param  [OpenStruct] decoded_response the decoded response to check for errors.
  # @return [Boolean] true if the failure is recoverable as described above.
  def override_taken_error?(decoded_response)
    errors = decoded_response&.errors&.assignment_override_students
    errors.present? && errors.all? { |error| error&.type == 'taken' }
  end

  ##
  # Moves a student into the right extension override, detaching them from
  # any override they currently belong to first (a student may only belong
  # to one adhoc override per assignment).
  #
  # @param  [Integer] course_id the course to provision the extension in.
  # @param  [Integer] student_id the student to provision the extension for.
  # @param  [Integer] assignment_id the assignment being extended.
  # @param  [OpenStruct|nil] student_override the student's current override, if any.
  # @param  [OpenStruct|nil] group_override the matching extension group override, if any.
  # @param  [String] override_title the title for the extension override.
  # @param  [String] new_due_date the new due date for the override.
  # @param  [String] new_close_date the close date for the override (maps to lock_at in Canvas API).
  # @return [Faraday::Response] the response from the final create/update call.
  def move_student_to_extension_override(course_id, student_id, assignment_id, student_override, group_override,
                                         override_title, new_due_date, new_close_date)
    if student_override
      if student_override.student_ids.length == 1 && group_override.nil?
        # The student is alone on their override and there is no group to
        # join: update it in place. Renaming the override here (e.g.
        # "1 day extension" -> "2 days extension") is safe since no other
        # student depends on it. Preserve the original unlock date so we
        # don't unlock the assignment earlier than intended.
        return update_assignment_override(
          course_id, assignment_id, student_override.id, student_override.student_ids, override_title,
          new_due_date, student_override.unlock_at, new_close_date
        )
      elsif student_override.student_ids.length == 1
        # Alone on their override but a matching group exists: the old
        # override would be left empty once they join the group, so delete it.
        delete_assignment_override(course_id, assignment_id, student_override.id)
      else
        # The override is shared with other students: pull this student out,
        # leaving its title and dates intact for the remaining students.
        remove_student_from_override(course_id, student_override, student_id)
      end
    end

    if group_override
      add_student_to_override(course_id, group_override, student_id)
    else
      create_assignment_override(
        course_id, assignment_id, [ student_id ], override_title, new_due_date,
        get_current_formatted_time, new_close_date
      )
    end
  end

  ##
  # Adds a student to an existing (group) override, keeping its title and
  # dates untouched for the students already in it.
  #
  # @param  [Integer] course_id the course the override belongs to.
  # @param  [OpenStruct] override the group override to add the student to.
  # @param  [Integer] student_id the student to add.
  # @return [Faraday::Response] the response from updating the override.
  def add_student_to_override(course_id, override, student_id)
    update_assignment_override(
      course_id,
      override.assignment_id,
      override.id,
      override.student_ids.map(&:to_i) | [ student_id.to_i ],
      override.title,
      override.due_at,
      override.unlock_at,
      override.lock_at
    )
  end
end
