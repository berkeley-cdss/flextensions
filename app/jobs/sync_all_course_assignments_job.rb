class SyncAllCourseAssignmentsJob < ApplicationJob
  queue_as :default

  def perform(course_to_lms_id, sync_user_id)
    # TODO: Replace this with just the course idea, then find all linked LMS.
    course_to_lms = CourseToLms.find(course_to_lms_id)
    sync_user = User.find(sync_user_id)
    # course = Course.find(course_to_lms.course_id)

    # TODO: This isn't great if we fire off two distinct jobs...
    results = {
      added_assignments: 0,
      updated_assignments: 0,
      unchanged_assignments: 0,
      disabled_assignments: 0
    }

    # @return [LmsFacade] facade for the LMS
    facade = Lms.facade_class(course_to_lms.lms_id).from_user(sync_user)
    # @return [Array<Lmss::BaseAssignment>] list of assignments from LMS
    lms_assignments = facade.get_all_assignments(course_to_lms.external_course_id)

    # Keep track of external assignment IDs from LMS
    external_assignment_ids = lms_assignments.map(&:id)

    # Sync or update assignments
    lms_assignments.each do |lms_assignment|
      sync_assignment(course_to_lms, lms_assignment, results)
    end

    # Disable assignments that no longer exist in the LMS instead of deleting
    # them, so their extension-request history is preserved. Skip when the LMS
    # returns no assignments at all — a bad or partial response should not
    # disable the whole course.
    if lms_assignments.any?
      missing_assignments = Assignment.where(course_to_lms_id: course_to_lms.id)
                                      .where.not(external_assignment_id: external_assignment_ids)
      # rubocop:disable Rails/SkipsModelValidations
      results[:disabled_assignments] = missing_assignments.update_all(enabled: false)
      # rubocop:enable Rails/SkipsModelValidations
    end

    results[:synced_at] = Time.current

    course_to_lms.recent_assignment_sync = results
    course_to_lms.save!
    results
  end

  # Sync a single assignment
  def sync_assignment(course_to_lms, lms_assignment, results)
    assignment = Assignment.find_or_initialize_by(course_to_lms_id: course_to_lms.id, external_assignment_id: lms_assignment.id)

    # Use shared LmsAssignment to populate Assignment
    assignment.name = lms_assignment.name
    assignment.due_date = lms_assignment.due_date
    assignment.late_due_date = lms_assignment.late_due_date
    assignment.external_assignment_id = lms_assignment.id

    if assignment.new_record?
      results[:added_assignments] += 1
    elsif assignment.changed?
      results[:updated_assignments] += 1
    else
      results[:unchanged_assignments] += 1
    end
    assignment.save!
  end
end
