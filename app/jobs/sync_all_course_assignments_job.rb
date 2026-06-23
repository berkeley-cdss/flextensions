class SyncAllCourseAssignmentsJob < ApplicationJob
  queue_as :default

  # Canvas omits the `all_dates` array (and therefore the base date) once an
  # assignment has more than this many dates/overrides. Without a base date we
  # cannot trust the root-level due date Canvas returns, since it may be derived
  # from an override and be later than the real assignment due date.
  OVERRIDE_DATE_LIMIT = 25

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
      deleted_assignments: 0
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

    # Delete assignments that no longer exist in LMS
    deleted_assignments = Assignment.where(course_to_lms_id: course_to_lms.id)
                                    .where.not(external_assignment_id: external_assignment_ids)
    deleted_assignments.destroy_all

    results[:deleted_assignments] = deleted_assignments.count
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
    assignment.external_assignment_id = lms_assignment.id

    if skip_due_date_update?(assignment, lms_assignment)
      log_skipped_due_date_update(course_to_lms, assignment, lms_assignment)
    else
      log_due_date_update(course_to_lms, assignment, lms_assignment)
      assignment.due_date = lms_assignment.due_date
      assignment.late_due_date = lms_assignment.late_due_date
    end

    if assignment.new_record?
      results[:added_assignments] += 1
    elsif assignment.changed?
      results[:updated_assignments] += 1
    else
      results[:unchanged_assignments] += 1
    end
    assignment.save!
  end

  # Don't overwrite due dates on a subsequent sync when Canvas can't give us a
  # reliable base date. With >= OVERRIDE_DATE_LIMIT overrides and no base_date,
  # the incoming dates may be derived from an override and be too late, so we
  # keep the previously-synced values instead of clobbering them.
  def skip_due_date_update?(assignment, lms_assignment)
    !assignment.new_record? &&
      lms_assignment.overrides_count >= OVERRIDE_DATE_LIMIT &&
      !lms_assignment.base_date?
  end

  def log_skipped_due_date_update(course_to_lms, assignment, lms_assignment)
    Rails.logger.warn(
      '[SyncAssignments] Skipping due date update for assignment ' \
      "#{lms_assignment.id} (course_to_lms=#{course_to_lms.id}): " \
      "#{lms_assignment.overrides_count} overrides and no base_date present. " \
      "Keeping stored due_date=#{assignment.due_date.inspect}, " \
      "late_due_date=#{assignment.late_due_date.inspect}; Canvas reported " \
      "due_date=#{lms_assignment.due_date.inspect}, " \
      "late_due_date=#{lms_assignment.late_due_date.inspect}."
    )
  end

  # Log the date signals for assignments that carry overrides so we can review
  # cases where the synced due date still looks wrong.
  def log_due_date_update(course_to_lms, assignment, lms_assignment)
    return unless lms_assignment.overrides_count.positive?

    Rails.logger.info(
      '[SyncAssignments] Updating due dates for assignment ' \
      "#{lms_assignment.id} (course_to_lms=#{course_to_lms.id}): " \
      "overrides=#{lms_assignment.overrides_count}, " \
      "base_date_present=#{lms_assignment.base_date?}, due_date " \
      "#{assignment.due_date.inspect} -> #{lms_assignment.due_date.inspect}, " \
      "late_due_date #{assignment.late_due_date.inspect} -> " \
      "#{lms_assignment.late_due_date.inspect}."
    )
  end
end
