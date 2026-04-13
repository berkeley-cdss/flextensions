class ApplicationMailer < ActionMailer::Base
  # TODO: Deprecate the EmailService class and move the render_templates method to this class.
  default from: ENV.fetch('DEFAULT_FROM_EMAIL', 'flextensions@berkeley.edu')
  default content_type: 'text/html'
  layout 'mailer'

  def generic_email(to:, from:, reply_to:, subject:, body:)
    mail(to: to, from: from, reply_to: reply_to, subject: subject, body: body)
  end
end
