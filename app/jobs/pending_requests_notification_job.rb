class PendingRequestsNotificationJob < ApplicationJob
  queue_as :default

  # Window the digest counts auto-approvals over, matched to how often the
  # digest for that frequency goes out.
  AUTO_APPROVAL_WINDOWS = {
    'hourly' => 1.hour,
    'daily' => 1.day,
    'weekly' => 1.week
  }.freeze

  def perform(frequency)
    window_start = AUTO_APPROVAL_WINDOWS.fetch(frequency).ago

    CourseSettings.with_pending_notifications(frequency).includes(:course).find_each do |cs|
      course = cs.course
      pending_requests = course.requests.pending.includes(:user, :assignment).order(:created_at).to_a
      next if pending_requests.empty?

      # Requests carry no approved-at timestamp, so updated_at is the closest
      # proxy for when an auto-approval happened.
      auto_approved_count = course.requests
                                  .where(status: 'approved', auto_approved: true)
                                  .where(updated_at: window_start..)
                                  .count

      PendingRequestsMailer.pending_requests_email(
        course_settings: cs,
        pending_requests: pending_requests,
        auto_approved_count: auto_approved_count,
        frequency: frequency
      ).deliver_now
    end
  end
end
