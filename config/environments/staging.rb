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

  # Keep GoodJob's in-process scheduler here. production.rb temporarily defaults
  # this to :external while we establish whether it is behind the production
  # health check failures; staging deploys cleanly today, so it stays on :async
  # and remains the working control. Remove this line once production.rb goes
  # back to :async.
  config.good_job.execution_mode = ENV.fetch('GOOD_JOB_EXECUTION_MODE', 'async').to_sym
end
