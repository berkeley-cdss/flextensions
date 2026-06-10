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
    UserToCourse::LEAD_TA_ROLE => 'Lead TA'
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
    teacher_courses + ta_courses
  end

  def role_query_param(role)
    normalized_role = UserToCourse.normalize_role(role)
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
  # @param  [String] course_id the Canvas course id to fetch assignments for.
  # @return [Faraday::Response] single page of assignments in the course.
  def get_assignments(course_id)
    @canvas_conn.get("courses/#{course_id}/assignments", {
      'include[]' => 'all_dates',
      'per_page' => 100
    })
  end

  ##
  # Gets all Canvas assignments for a course (paginated).
  #
  # @param  [String] course_id the Canvas course id to fetch assignments for.
  # @return [Array<Lmss::Canvas::Assignment>] list of assignments in the course.
  def get_all_assignments(course_id)
    assignments = depaginate_response(get_assignments(course_id))

    # Process assignments to extract base dates
    assignments.map do |assignment_data|
      # Unpack base date from all_dates array
      if assignment_data['all_dates']
        base_date = assignment_data['all_dates'].find { |date| date['base'] == true }
        assignment_data['base_date'] = base_date
      elsif assignment_data['has_overrides']
        # Canvas omits all_dates once an assignment has more than 25 dates, and
        # the top-level due_at may then reflect an override's date rather than
        # the base date, so explicitly query the base ("Everyone") dates.
        assignment_data['base_date'] = get_base_dates(course_id, assignment_data['id'])
      end
      # Return as Lmss::Canvas::Assignment object
      Lmss::Canvas::Assignment.new(assignment_data)
    end
  end

  ##
  # Gets a specified assignment from a course.
  #
  # @param  [Integer] courseId     the course to fetch the assignment from.
  # @param  [Integer] assignmentId the id of the assignment to fetch.
  # @return [Faraday::Response] information about the requested assignment.
  def get_assignment(courseId, assignmentId)
    @canvas_conn.get("courses/#{courseId}/assignments/#{assignmentId}")
  end

  ##
  # Gets the date details for an assignment.
  # The top-level due_at/unlock_at/lock_at of this response are always the
  # base ("Everyone") dates, regardless of how many overrides exist.
  #
  # @param  [Integer] course_id     the course the assignment belongs to.
  # @param  [Integer] assignment_id the assignment to fetch date details for.
  # @return [Faraday::Response] the date details for the assignment.
  def get_assignment_date_details(course_id, assignment_id)
    @canvas_conn.get("courses/#{course_id}/assignments/#{assignment_id}/date_details")
  end

  ##
  # Explicitly fetches the base (i.e. "Everyone"/all students) dates for an assignment.
  #
  # The assignment endpoints cannot be trusted for this: Canvas omits all_dates
  # when an assignment has more than 25 dates, and due_at may then be an
  # override's date. This uses the date_details endpoint, whose top-level dates
  # are always the base dates.
  #
  # @param  [Integer] course_id     the course the assignment belongs to.
  # @param  [Integer] assignment_id the assignment to fetch the base dates for.
  # @return [Hash, nil] hash with 'due_at', 'unlock_at', 'lock_at' and
  #                     'base' => true (matching the all_dates format), or nil
  #                     if the dates could not be fetched.
  def get_base_dates(course_id, assignment_id)
    response = get_assignment_date_details(course_id, assignment_id)
    return nil unless response.success?

    details = JSON.parse(response.body)
    details.slice('due_at', 'unlock_at', 'lock_at').merge('base' => true)
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
  # If the student already has an override:
  # - and they are the only student on it, the override is updated in place.
  #   This includes renaming the override (e.g. an override staff titled
  #   "1 day extension" becomes "<student> extended to <date>"); Canvas
  #   accepts a title change on update.
  # - and it is shared with other students (e.g. a group override titled
  #   "2 days extension"), the student is removed from the shared override --
  #   keeping its title and dates intact for the remaining students -- and a
  #   new individual override is created for this student.
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
    override_title = "#{student_id} extended to #{new_due_date}"

    # Find the student's existing override, if any. This searches *all*
    # overrides (depaginated), since an assignment may have well over a page
    # of overrides.
    student_override = get_existing_student_override(course_id, student_id, assignment_id)

    response = if student_override.nil?
      create_assignment_override(
        course_id, assignment_id, [ student_id ], override_title, new_due_date,
        get_current_formatted_time, new_close_date
      )
    else
      handle_override_logic(
        course_id, student_override, student_id, assignment_id, override_title,
        new_due_date, new_close_date
      )
    end
    decoded_response = parse_create_response(response)

    # Canvas reports 'taken' when the student already belongs to an override,
    # e.g. one created between our lookup above and the create call.
    if response.status == 400 && override_taken_error?(decoded_response)
      curr_override = fetch_existing_override(course_id, student_id, assignment_id)
      response = handle_override_logic(
        course_id, curr_override, student_id, assignment_id, override_title,
        new_due_date, new_close_date
      )
      decoded_response = parse_create_response(response)
    end

    unless (200..299).cover?(response.status)
      raise CanvasAPIError, "Canvas could not save the extension (HTTP #{response.status})"
    end

    Lmss::Canvas::Override.new(decoded_response)
  end

  private

  ##
  # Gets the existing override for a student.
  #
  # @param  [Integer] courseId the courseId to check for an existing override.
  # @param  [Integer] studentId the student to check for an existing override for.
  # @param  [Integer] assignmentId the assignmnet to check for an existing override for.
  # @return [OpenStruct|nil] the override if it is found or nil if not.
  # @throws [FailedPipelineError] if the existing overrides response body could not be parsed.
  def get_existing_student_override(course_id, student_id, assignment_id)
    begin
      # Depaginate: with many overrides (e.g. > 25) the student's override may
      # not be on the first page, and missing it here would orphan it.
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

    all_assignment_overrides.each do |override_data|
      override = OpenStruct.new(override_data)
      return override if override.student_ids&.map(&:to_i)&.include?(student_id.to_i)
    end
    nil
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
  # Fetches the existing override for a student.
  #
  # @param  [Integer] courseId the courseId to fetch the override for.
  # @param  [Integer] studentId the studentId to fetch the override for.
  # @param  [Integer] assignmentId the assignmentId to fetch the override for.
  # @return [OpenStruct] the existing override.
  # @raises [NotFoundError] if the override could not be found.
  def fetch_existing_override(courseId, studentId, assignmentId)
    curr_override = get_existing_student_override(courseId, studentId, assignmentId)
    raise NotFoundError, 'could not find student\'s override' if curr_override.nil?

    curr_override
  end

  ##
  # Handles the logic for updating or creating an override.
  #
  # @param  [Integer] courseId the courseId to handle the override logic for.
  # @param  [OpenStruct] curr_override the current override to handle the logic for.
  # @param  [Integer] studentId the studentId to handle the override logic for.
  # @param  [Integer] assignmentId the assignmentId to handle the override logic for.
  # @param  [String] overrideTitle the title of the override.
  # @param  [String] newDueDate the new due date for the override.
  # @param  [String] newCloseDate the close date for the override (maps to lock_at in Canvas API).
  # @return [Faraday::Response] the response from updating or creating the override.
  def handle_override_logic(courseId, curr_override, studentId, assignmentId, overrideTitle, newDueDate, newCloseDate)
    if curr_override.student_ids.length == 1
      # The student is the only one on the override: update it in place.
      # Renaming the override here is safe since no other student depends on
      # it. Preserve the original unlock date so we don't unlock the
      # assignment earlier than intended.
      update_assignment_override(
        courseId, assignmentId, curr_override.id, curr_override.student_ids, overrideTitle, newDueDate,
        curr_override.unlock_at, newCloseDate
      )
    else
      # The override is shared with other students: pull this student out of
      # it (leaving its title and dates intact) and give them their own.
      remove_student_from_override(courseId, curr_override, studentId)
      create_assignment_override(
        courseId, assignmentId, [ studentId ], overrideTitle, newDueDate, get_current_formatted_time, newCloseDate
      )
    end
  end
end
