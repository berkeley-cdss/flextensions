# frozen_string_literal: true

# ActionMailer interceptor used in the staging environment to ensure we never
# email real people. Every outgoing message is redirected to a single safe
# staging mailbox, and the original recipient(s) are preserved in the subject
# line so the rendered email can still be inspected.
#
# Registered in config/environments/staging.rb via:
#   config.action_mailer.interceptors = %w[StagingEmailInterceptor]
class StagingEmailInterceptor
  # Address that all staging mail is redirected to. Can be overridden with the
  # STAGING_EMAIL_OVERRIDE env var if a different staging inbox is desired.
  DEFAULT_OVERRIDE = 'flextensions@berkeley.edu'

  def self.delivering_email(message)
    original_recipients = Array(message.to).join(', ')
    message.subject = "[STAGING -> #{original_recipients}] #{message.subject}"

    message.to  = ENV.fetch('STAGING_EMAIL_OVERRIDE', DEFAULT_OVERRIDE)
    message.cc  = nil
    message.bcc = nil
  end
end
