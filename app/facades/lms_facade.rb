##
# Base class for all extension facades.
#
# The goal of a facade is to provide a consistent interface to different services,
# e.g. to make bCourses and Gradescope operate in the same way (to the rest of the
# the app) even though their APIs are different.
#
# We should have consistent names for all the common methods, though individual
# subclasses will likely implement additional methods.
#
# We have to deal with 'objects', either 'Plain Old Ruby Objects' (POROs) or
# ActiveRecord models, rather than Faraday responses and individual service ids
# as much as possible.
#
#
class LmsFacade
  class LmsAPIError < StandardError; end

  # Every facade must accept at least one optional argument for compatibility.
  # This is usually the user token, or some other value passed to the supporting API.
  def initialize(_user_token = nil)
    raise NotImplementedError
  end

  # It is useful to be able to create an instance from a user object.
  # We expect each facade to implement this method.
  def self.from_user(user)
    # token = user.canvas_token # or however you extract the token
    # new(token)
    raise NotImplementedError
  end

  ##
  # Builds the URL to an assignment in the LMS's web UI. Each LMS owns its own
  # URL structure, so subclasses implement this rather than callers assuming a
  # shared shape across LMSs.
  #
  # @param  [String] base_url the LMS base URL (e.g. https://bcourses.berkeley.edu).
  # @param  [String] external_course_id the course's id in the LMS.
  # @param  [String] external_assignment_id the assignment's id in the LMS.
  # @return [String] the URL to the assignment.
  def self.assignment_url(base_url, external_course_id, external_assignment_id)
    raise NotImplementedError
  end

  ##
  # It's not clear whether this needs to exist for all facades.
  # Many APIs paginate responses, and we should be able to use 1 method
  # to handle depagination
  # Typically we will write something like `get_all_courses`
  # Which is a call to some_facade.depaginate_response(some_facade.get_courses)
  def depaginate_response(response)
    raise NotImplementedError
  end

  ##
  # Fetches all assignments from LMS for a given course.
  #
  # @param   [String] external_course_id the external course ID in the LMS.
  # @return  [Array<Lmss::BaseAssignment>] list of assignments.
  def get_all_assignments(external_course_id)
    raise NotImplementedError
  end

  ## Fetch existing extensions for an assignment
  #
  # @param   [String] external_course_id the external course ID in the LMS.
  # @param   [String] external_assignment_id the external assignment ID in the LMS.
  # @return  [Array<Lmss::BaseExtension>] list of existing extensions for assignment.
  def get_assignment_overrides(external_course_id, external_assignment_id)
    raise NotImplementedError
  end

  ##
  # Provisions a new extension to a user.
  #
  # @param   [Integer] courseId the course to provision the extension in.
  # @param   [Integer] studentId the student to provisoin the extension for.
  # @param   [Integer] assignmentId the assignment the extension should be provisioned for.
  # @param   [String]  newDueDate the date the assignment should be due.
  # @return  [Lmss::BaseExtension] the extension that was provisioned.
  def provision_extension(course_id, student_id, assignment_id, new_due_date)
    raise NotImplementedError
  end

  ##
  # The value this LMS uses to identify a student in the extension methods.
  #
  # @param  [User] user the student.
  # @return [Object] the identifier passed as student_id to the extension methods.
  def student_identifier(user)
    raise NotImplementedError
  end

  ##
  # Reads the due date of every student-specific extension on an assignment.
  #
  # @param  [String] course_id the course the assignment belongs to.
  # @param  [String] assignment_id the assignment to read extensions from.
  # @return [Hash{Object => Time}] due dates, keyed by student_identifier.
  # @raises [StandardError] if the extensions could not be read, so that a
  #         failure is never mistaken for an assignment with no extensions.
  def extension_due_dates(course_id, assignment_id)
    raise NotImplementedError
  end

  ##
  # Removes a student's extension, so the assignment's own dates apply to them.
  #
  # @param  [String] course_id the course the assignment belongs to.
  # @param  [Object] student_id the student, as given by student_identifier.
  # @param  [String] assignment_id the assignment to remove the extension from.
  # @return [Boolean] true if an extension was removed, false if there was none.
  # @raises [StandardError] if the extension could not be removed.
  def remove_extension(course_id, student_id, assignment_id)
    raise NotImplementedError
  end
end
