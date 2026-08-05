# frozen_string_literal: true

# Templates and delivery helper for the "you have N pending extension requests"
# digest email that PendingRequestsNotificationJob sends. Wraps EmailService so
# the job doesn't need to know the template strings or mapping shape.
class PendingRequestsMailer
  SUBJECT_TEMPLATE = '{{pending_count}} Pending Extension Request{{plural}} - {{course_code}}'

  BODY_TEMPLATE = <<~BODY
    Hello,

    You have {{pending_count}} pending extension request{{plural}} in {{course_name}} ({{course_code}}).

    Please review them at: {{requests_url}}

    Thank you,
    Flextensions
  BODY

  def self.send_pending_request_notifications(course_settings, pending_count, requests_url)
    course = course_settings.course
    default_from = ENV.fetch('DEFAULT_FROM_EMAIL')

    EmailService.send_email(
      to: course_settings.pending_notification_email,
      from: default_from,
      reply_to: course_settings.reply_email.presence || default_from,
      subject_template: SUBJECT_TEMPLATE,
      body_template: BODY_TEMPLATE,
      mapping: {
        'pending_count' => pending_count.to_s,
        'plural' => pending_count == 1 ? '' : 's',
        'course_name' => course.course_name,
        'course_code' => course.course_code,
        'requests_url' => requests_url
      },
      deliver_later: false
    )
  end
end
