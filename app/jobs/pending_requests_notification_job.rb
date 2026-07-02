class PendingRequestsNotificationJob < ApplicationJob
  queue_as :default

  def perform(frequency)
    CourseSettings.with_pending_notifications(frequency).includes(:course).find_each do |cs|
      course = cs.course
      pending_count = Request.where(course_id: course.id, status: 'pending').count
      next if pending_count.zero?

      requests_url = "#{ENV.fetch('APP_HOST', nil)}/courses/#{course.id}/requests"

      PendingRequestsMailer.send_pending_request_notifications(cs, pending_count, requests_url)
    end
  end
end
