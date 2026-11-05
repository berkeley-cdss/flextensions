# Removes LMS extensions that have left a student with an earlier deadline than
# the rest of the class. An LMS keeps using a student's override even when the
# assignment's own deadline moves past it, so once that happens the extension
# only hurts the student. Without it, they follow the class deadline, including
# any future changes to it.
#
# An extension is only removed if its date matches one Flextensions approved for
# that student. Staff may have set any other date on purpose, so those are left
# alone and counted as skipped. Requests are not changed, which keeps the history
# of what was approved. The LMS is the record of what still needs removing, so
# running this again changes nothing and retries anything that failed.
class StaleExtensionRemover
  # An LMS can adjust the seconds of the date it stores, for example turning
  # 11:59:00pm into 11:59:59pm.
  SAME_DATE_TOLERANCE = 1.minute

  # @param course_to_lms [CourseToLms] the course's link to the LMS.
  # @param facade [LmsFacade] the facade to use, already acting as a staff user.
  def initialize(course_to_lms, facade)
    @course_to_lms = course_to_lms
    @facade = facade
  end

  # @param external_assignment_ids [Array] the assignments that still exist in the LMS.
  # @return [Hash] the number of students :removed, :skipped, and :failed.
  def call(external_assignment_ids)
    @totals = { removed: 0, skipped: 0, failed: 0 }

    stale_requests(external_assignment_ids).group_by(&:assignment).each do |assignment, requests|
      review_assignment(assignment, requests.group_by(&:user))
    end

    @totals
  end

  private

  def stale_requests(external_assignment_ids)
    Request.approved_before_current_deadline
           .where(assignments: { course_to_lms_id: @course_to_lms.id, external_assignment_id: external_assignment_ids })
           .includes(:assignment, :user)
  end

  # Reads the LMS once per assignment. Requests stay out of date after their
  # extension is removed, so reading once per student would repeat on every sync.
  def review_assignment(assignment, requests_by_user)
    due_dates = @facade.extension_due_dates(external_course_id, assignment.external_assignment_id)

    requests_by_user.each do |user, requests|
      review_student(assignment, user, requests, due_dates[@facade.student_identifier(user)])
    end
  rescue StandardError => e
    report_failure(e, assignment)
    @totals[:failed] += requests_by_user.size
  end

  def review_student(assignment, user, requests, lms_due_date)
    # No extension is left, or a later one is still in place.
    return unless lms_due_date && lms_due_date < assignment.due_date

    if requests.any? { |request| same_date?(request.requested_due_date, lms_due_date) }
      remove_extension(assignment, user)
    else
      Rails.logger.info "Left an earlier extension in place for user #{user.id} on assignment #{assignment.id}: " \
                        'its date does not match an approved request.'
      @totals[:skipped] += 1
    end
  end

  def remove_extension(assignment, user)
    student_id = @facade.student_identifier(user)
    @facade.remove_extension(external_course_id, student_id, assignment.external_assignment_id)
    @totals[:removed] += 1
  rescue StandardError => e
    report_failure(e, assignment, user)
    @totals[:failed] += 1
  end

  def same_date?(first, second)
    (first - second).abs < SAME_DATE_TOLERANCE
  end

  def external_course_id
    @course_to_lms.external_course_id
  end

  def report_failure(error, assignment, user = nil)
    Rails.logger.error "Failed to remove an outdated extension on assignment #{assignment.id}: #{error.message}"
    Rails.error.report(error, handled: true,
                       context: { component: 'stale_extensions', assignment_id: assignment.id, user_id: user&.id,
                                  lms: @facade.class.name })
  end
end
