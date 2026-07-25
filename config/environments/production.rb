require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from `public/`, relying on NGINX/Apache to do so instead.
  # config.public_file_server.enabled = false

  # Compress CSS using a preprocessor.
  # config.assets.css_compressor = :sass

  # Do not fall back to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]
  config.hosts.clear

  # TLS is terminated at the load balancer, which forwards plain HTTP to the
  # app. assume_ssl tells Rails to treat those forwarded requests as secure so
  # force_ssl does not redirect-loop; force_ssl then redirects any HTTP access
  # to HTTPS, sends Strict-Transport-Security, and marks cookies secure.
  config.assume_ssl = true
  config.force_ssl = true

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

  # Use a real queuing backend for Active Job (and separate queues per environment).
  # The adapter itself is set in config/application.rb (config.active_job.queue_adapter = :good_job).
  # config.active_job.queue_name_prefix = "flextensions_production"

  # --- Background jobs (GoodJob) ---
  # Run GoodJob *inside* the Puma web process using its own in-process scheduler
  # and worker thread pool (separate from Puma's request threads). This suits a
  # single-instance-per-environment deployment: no separate worker process or
  # tier is required, and it does not depend on Elastic Beanstalk starting a
  # Procfile `worker` process.
  #
  # To scale out later (dedicated worker tier or multiple web instances), switch
  # execution_mode to :external here and run `bundle exec good_job start` as its
  # own process (e.g. via a Procfile `worker` entry or a systemd unit).
  config.good_job.execution_mode = :async
  config.good_job.max_threads = ENV.fetch("GOOD_JOB_MAX_THREADS", 5).to_i
  config.good_job.poll_interval = ENV.fetch("GOOD_JOB_POLL_INTERVAL", 30).to_i
  config.good_job.shutdown_timeout = 25
  config.good_job.queues = ENV.fetch("GOOD_JOB_QUEUES", "*")
  config.good_job.enable_cron = false

  # config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Generate these keys by running:
  # head -c 32 /dev/urandom | base64
  config.active_record.encryption.primary_key =
    ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
  config.active_record.encryption.deterministic_key =
    ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"]
  config.active_record.encryption.key_derivation_salt =
    ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
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
