class AutomaticEnrollmentSyncJob < ApplicationJob
  queue_as :default

  MAX_COURSE_AGE = 5.weeks
  MINIMUM_SYNC_INTERVAL = 6.hours

  # The daily sweep schedules this job ahead of time, so recheck every
  # condition when it actually runs. An instructor may have manually synced
  # the roster, or their Canvas credential may have disappeared, since the
  # sweep was performed.
  def perform(course_id)
    course = Course.find_by(id: course_id)
    return unless course
    return unless self.class.due?(course)

    sync_user = self.class.sync_user_for(course, require_fresh_token: true)
    return unless sync_user

    course.sync_all_enrollments_from_canvas(sync_user.id)
  end

  def self.due?(course, at: Time.current)
    return false if course.created_at < at - MAX_COURSE_AGE

    canvas_link = course.course_to_lms(CANVAS_LMS_ID)
    return false if canvas_link&.external_course_id.blank?

    last_synced_at = parse_sync_time(canvas_link.recent_roster_sync&.dig('synced_at'))
    last_synced_at.nil? || last_synced_at <= at - MINIMUM_SYNC_INTERVAL
  end

  def self.sync_user_for(course, require_fresh_token: false)
    candidates = course.staff_users_for_auto_approval
    return candidates.first unless require_fresh_token

    candidates.find { |user| user.ensure_fresh_canvas_token!.present? }
  end

  def self.parse_sync_time(value)
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
  private_class_method :parse_sync_time
end
