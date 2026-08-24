# config/environments/staging.rb

# Load the production environment settings as a base
# and override specific settings for staging.
require_relative './production'

Rails.application.configure do
  # Staging-specific overrides
  config.log_level = :debug
  # Show full error reports, OK because staging is behind a VPN
  config.consider_all_requests_local = true

  # Ensure staging never emails real people: redirect every outgoing message to
  # a single safe staging mailbox, preserving the original recipient(s) in the
  # subject line. See StagingEmailInterceptor.
  config.action_mailer.interceptors = %w[StagingEmailInterceptor]
end
