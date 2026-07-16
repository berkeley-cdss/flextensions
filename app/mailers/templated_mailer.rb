# frozen_string_literal: true

# Delivers a pre-rendered HTML email. The subject and body are already
# interpolated by EmailService, so the action just wraps them in a message
# rather than rendering a view template.
class TemplatedMailer < ApplicationMailer
  def templated_email(to:, from:, reply_to:, subject:, body:)
    mail(
      to: to,
      from: from,
      reply_to: reply_to,
      subject: subject,
      body: body,
      content_type: 'text/html'
    )
  end
end
