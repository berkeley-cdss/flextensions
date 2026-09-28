# frozen_string_literal: true

# The "you have N pending extension requests" digest email that
# PendingRequestsNotificationJob sends to course staff. Rendered from ERB views
# in app/views/pending_requests_mailer/.
class PendingRequestsMailer < ApplicationMailer
  # How the digest describes the window auto-approvals are counted over
  # ("In the past hour ..."), keyed by the course's notification frequency.
  PERIOD_LABELS = {
    'hourly' => 'hour',
    'daily' => 'day',
    'weekly' => 'week'
  }.freeze

  # Very large courses can accumulate hundreds of pending requests; cap the
  # per-request list so the digest stays readable and link to the requests
  # page for the rest.
  MAX_LISTED_REQUESTS = 50

  def pending_requests_email(course_settings:, pending_requests:, auto_approved_count:, frequency:)
    @course = course_settings.course
    @pending_requests = pending_requests
    @listed_requests = pending_requests.first(MAX_LISTED_REQUESTS)
    @unlisted_count = pending_requests.size - @listed_requests.size
    @auto_approved_count = auto_approved_count
    @period_label = PERIOD_LABELS.fetch(frequency)

    default_from = ENV.fetch('DEFAULT_FROM_EMAIL')
    count = pending_requests.size

    mail(
      to: course_settings.pending_notification_email,
      from: default_from,
      reply_to: course_settings.reply_email.presence || default_from,
      subject: "#{count} Pending Extension Request#{'s' unless count == 1} - #{@course.course_code}"
    )
  end
end
