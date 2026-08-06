require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Flextensions
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.active_record.default_timezone = :utc
    config.time_zone = 'Pacific Time (US & Canada)'
    config.generators.system_tests = nil
    config.active_job.queue_adapter = :good_job

    # Recurring jobs, run by GoodJob's built-in cron. The schedule is defined
    # for every environment so it is visible in one place, but GoodJob only acts
    # on it where `enable_cron` is true (production/staging — see
    # config/environments/production.rb).
    #
    # Times are Pacific (the timezone is the trailing cron field) so they match
    # what instructors see in course settings, regardless of the server clock.
    # Each occurrence is enqueued at most once even if several processes are
    # running: GoodJob has a unique index on (cron_key, cron_at).
    config.good_job.cron = {
      pending_digests_hourly: {
        cron: '0 * * * * America/Los_Angeles',
        class: 'PendingRequestsNotificationJob',
        args: [ 'hourly' ],
        description: 'Pending extension request digests for courses set to hourly'
      },
      pending_digests_daily: {
        cron: '0 16 * * * America/Los_Angeles',
        class: 'PendingRequestsNotificationJob',
        args: [ 'daily' ],
        description: 'Pending extension request digests for courses set to daily'
      },
      pending_digests_weekly: {
        cron: '0 16 * * 4 America/Los_Angeles',
        class: 'PendingRequestsNotificationJob',
        args: [ 'weekly' ],
        description: 'Pending extension request digests for courses set to weekly'
      }
    }

    # We do not require the master key and insetad use environment variables
    # Review .env.example for required variables.
    config.require_master_key = false
  end
end
