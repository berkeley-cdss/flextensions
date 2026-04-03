Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  # config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Setup logging with Lograge [https://github.com/roidrage/lograge]
  # See config/initializers/lograge.rb for more details.
  config.lograge.enabled = true

  # "info" includes generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Disable query logging
  # config.active_record.logger = nil
  # config.logger = ActiveSupport::Logger.new(STDOUT)
  #   .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
  #   .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  # # Prepend all log lines with the following tags.
  # config.log_tags = [ :request_id ]

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # config.active_job.queue_adapter = :resque

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false


  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }


  if ENV["ACTION_MAILER_DELIVERY_METHOD"] == "smtp"
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address:              ENV.fetch("SMTP_ADDRESS"),
      port:                 ENV.fetch("SMTP_PORT").to_i,
      domain:               ENV.fetch("SMTP_DOMAIN"),
      user_name:            ENV["SMTP_USERNAME"],
      password:             ENV["SMTP_PASSWORD"],
      authentication:       ENV.fetch("SMTP_AUTH_METHOD", nil),
      enable_starttls_auto: ENV.fetch("SMTP_ENABLE_STARTTLS", "false") == "true",
      ssl:                  ENV.fetch("SMTP_SSL", "false") == "true",
      open_timeout:         30,
      read_timeout:         60
    }
  else
    config.action_mailer.delivery_method = :sendmail
  end

  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST", "localhost"),
    port: ENV.fetch("APP_PORT", "3000")
  }
end
