class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  private

  # Records a failed sync on a CourseToLms status column (:recent_roster_sync
  # or :recent_assignment_sync) so the UI can tell the user what happened,
  # preserving the data from the last successful sync. Must never raise: it
  # runs while the original error is being re-raised, and that error is the
  # one that has to reach the error reporter. Pass `message:` when the raw
  # exception message would be meaningless to the user.
  def record_sync_failure(course_to_lms, field, error, message: nil)
    return unless course_to_lms

    record = (course_to_lms.public_send(field) || {}).merge(
      'error' => (message || error.message).to_s.truncate(300),
      'failed_at' => Time.current
    )
    course_to_lms.update!(field => record)
  rescue StandardError => e
    Rails.logger.error "Failed to record sync failure on CourseToLms #{course_to_lms&.id}: #{e.message}"
  end
end
