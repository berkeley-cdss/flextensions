class DailyEnrollmentSyncJob < ApplicationJob
  queue_as :default

  SPREAD_WINDOW = 1.hour

  # Find recently imported courses that are due for a roster refresh, then
  # distribute their syncs across the next hour instead of creating a burst of
  # Canvas API traffic at 3:00 AM.
  def perform
    sweep_started_at = Time.current
    courses = candidate_courses(sweep_started_at).select do |course|
      AutomaticEnrollmentSyncJob.due?(course, at: sweep_started_at) &&
        AutomaticEnrollmentSyncJob.sync_user_for(course).present?
    end

    courses.each_with_index do |course, index|
      delay = SPREAD_WINDOW.to_f * index / courses.length
      AutomaticEnrollmentSyncJob.set(wait: delay).perform_later(course.id)
    end

    courses.length
  end

  private

  def candidate_courses(at)
    Course.joins(:course_to_lmss)
          .where(courses: { created_at: (at - AutomaticEnrollmentSyncJob::MAX_COURSE_AGE).. })
          .where(course_to_lmss: { lms_id: CANVAS_LMS_ID })
          .where.not(course_to_lmss: { external_course_id: nil })
          .includes(enrollments: { user: :lms_credentials })
          .distinct
          .order('courses.id')
          .to_a
  end
end
