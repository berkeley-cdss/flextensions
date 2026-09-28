# frozen_string_literal: true

Faultline.configure do |config|
  # =============================================================================
  # User Configuration
  # =============================================================================

  # User class for association (default: "User")
  config.user_class = "User"

  # Method to get current user in controllers
  config.user_method = :current_user

  # Custom context - add extra data to every error occurrence.
  #
  # Faultline already records the `User` returned by `current_user` above
  # (its id and email show up on the occurrence as the "user"), but that only
  # works when the exception reaches the middleware with a controller instance
  # in the Rack env. Errors raised earlier in the stack -- in another
  # middleware, in the session store, before the controller is built -- have
  # no controller to ask, and an anonymous request resolves to a NullUser whose
  # id is nil. So we also attach the Canvas uid straight from the session as a
  # context entry, which is the "basic user ID" the team looks up first: it is
  # what the Canvas dashboard and the users table are keyed on, and it is
  # present for every signed-in request regardless of where the error came
  # from. Each key becomes a Faultline::ErrorContext row on the occurrence.
  config.custom_context = lambda { |request, _env|
    canvas_uid = request.session[:user_id]
    { canvas_uid: canvas_uid.presence }.compact
  }

  # =============================================================================
  # Error Filtering
  # =============================================================================

  # Exceptions to ignore (won't be tracked)
  config.ignored_exceptions = [
    "ActiveRecord::RecordNotFound",
    "ActionController::RoutingError",
    "ActionController::UnknownFormat",
    "ActionController::InvalidAuthenticityToken",
    "ActionController::BadRequest"
  ]

  # User agents to ignore (bots, crawlers)
  config.ignored_user_agents = [
    /bot/i, /crawler/i, /spider/i, /Googlebot/i, /Bingbot/i, /Slurp/i
  ]

  # =============================================================================
  # Dashboard Authentication
  # =============================================================================

  # Gate the dashboard to admins only.
  #
  # This lambda is instance_exec'd inside Faultline's own controller, which does
  # not have the app's `current_user` helper, so we resolve the user the same way
  # ApplicationController#current_user does (User.find_by(canvas_uid:
  # session[:user_id])) and then require `admin?`.
  config.authenticate_with = lambda { |request|
    user = User.find_by(canvas_uid: request.session[:user_id])
    !!user&.admin?
  }

  # Optional: Additional authorization after authentication
  # config.authorize_with = lambda { |request|
  #   # Add extra authorization logic here
  #   true
  # }

  # =============================================================================
  # Notifications
  # =============================================================================

  # App name for notifications (shown in alert messages)
  config.app_name = Rails.application.class.module_parent_name

  # Notification rules - when to send alerts
  config.notification_rules = {
    on_first_occurrence: true,           # Alert on new error types
    on_reopen: true,                     # Alert when resolved errors reoccur
    on_threshold: [10, 50, 100, 500],    # Alert at these occurrence counts
    critical_exceptions: [],              # Always alert for these exception classes
    notify_in_environments: ["production"]
  }

  # --- Telegram Notifier ---
  # Store credentials in Rails credentials:
  #   rails credentials:edit
  #   faultline:
  #     telegram:
  #       bot_token: "your-bot-token"
  #       chat_id: "your-chat-id"
  #       message_thread_id: 123 # optional, for forum topics
  #
  # if Rails.application.credentials.dig(:faultline, :telegram, :bot_token)
  #   config.add_notifier(
  #     Faultline::Notifiers::Telegram.new(
  #       bot_token: Rails.application.credentials.dig(:faultline, :telegram, :bot_token),
  #       chat_id: Rails.application.credentials.dig(:faultline, :telegram, :chat_id),
  #       message_thread_id: Rails.application.credentials.dig(:faultline, :telegram, :message_thread_id)
  #     )
  #   )
  # end

  # --- Slack Notifier ---
  # Store webhook URL in Rails credentials:
  #   rails credentials:edit
  #   faultline:
  #     slack:
  #       webhook_url: "https://hooks.slack.com/services/..."
  #
  # if Rails.application.credentials.dig(:faultline, :slack, :webhook_url)
  #   config.add_notifier(
  #     Faultline::Notifiers::Slack.new(
  #       webhook_url: Rails.application.credentials.dig(:faultline, :slack, :webhook_url),
  #       channel: "#errors",
  #       username: "Faultline"
  #     )
  #   )
  # end

  # --- Discord Notifier ---
  # Store webhook URL in Rails credentials:
  #   rails credentials:edit
  #   faultline:
  #     discord:
  #       webhook_url: "https://discord.com/api/webhooks/..."
  #
  # if Rails.application.credentials.dig(:faultline, :discord, :webhook_url)
  #   config.add_notifier(
  #     Faultline::Notifiers::Discord.new(
  #       webhook_url: Rails.application.credentials.dig(:faultline, :discord, :webhook_url),
  #       username: "Faultline",
  #       avatar_url: nil,         # optional, overrides the webhook's avatar
  #       mention: nil             # optional, e.g. "<@&ROLE_ID>" or "@everyone"
  #     )
  #   )
  # end

  # --- Generic Webhook Notifier ---
  # For custom integrations (PagerDuty, Opsgenie, etc.)
  #
  # config.add_notifier(
  #   Faultline::Notifiers::Webhook.new(
  #     url: ENV["FAULTLINE_WEBHOOK_URL"],
  #     method: :post,
  #     headers: { "Authorization" => "Bearer #{ENV['FAULTLINE_WEBHOOK_TOKEN']}" }
  #   )
  # )

  # --- Resend Email Notifier ---
  # Sends error notifications via Resend API (https://resend.com)
  # Store API key in Rails credentials:
  #   rails credentials:edit
  #   faultline:
  #     resend:
  #       api_key: "re_xxxxx"
  #
  # if Rails.application.credentials.dig(:faultline, :resend, :api_key)
  #   config.add_notifier(
  #     Faultline::Notifiers::Resend.new(
  #       api_key: Rails.application.credentials.dig(:faultline, :resend, :api_key),
  #       from: "errors@yourdomain.com",
  #       to: "team@example.com"            # or array: ["dev@example.com", "ops@example.com"]
  #     )
  #   )
  # end

  # --- Email Notifier (ActionMailer) ---
  # Sends error notifications through the app's existing mail configuration
  # (SMTP/sendmail in production) with deliver_later on GoodJob. Fires per the
  # notification_rules above: only in the notify_in_environments list, for new
  # error groups, reopened errors, and occurrence-count thresholds.
  config.add_notifier(
    Faultline::Notifiers::Email.new(
      to: "flextensions@berkeley.edu",
      from: ENV["DEFAULT_FROM_EMAIL"] # nil falls back to the ActionMailer default
    )
  )

  # Notification cooldown - prevent spam during error storms (nil to disable)
  config.notification_cooldown = 5.minutes

  # =============================================================================
  # GitHub Integration
  # =============================================================================

  # Create GitHub issues from error groups with full context.
  # Store credentials in Rails credentials:
  #   rails credentials:edit
  #   faultline:
  #     github:
  #       token: "ghp_xxxxx"
  #
  # config.github_repo = "your-org/your-repo"
  # config.github_token = Rails.application.credentials.dig(:faultline, :github, :token)

  # Labels to add to created issues (customize for your workflow)
  # Add "faultline-auto-fix" to trigger AI auto-fix via GitHub Actions
  # config.github_labels = ["bug", "faultline", "faultline-auto-fix"]

  # =============================================================================
  # Error Capture Configuration
  # =============================================================================

  # Enable Rack middleware to catch unhandled exceptions automatically
  config.enable_middleware = true

  # Subscribe to Rails error reporting API (Rails.error.report/handle/record)
  # This captures errors from background jobs and explicit Rails.error calls
  config.register_error_subscriber = true

  # Paths to ignore (no error tracking for these).
  # /status/health_check is the load balancer health check endpoint
  # (StatusController#health_check); it reports database failures in its JSON
  # body rather than raising. /admin/faultline is the engine itself
  # (config/routes.rb).
  config.middleware_ignore_paths = ["/assets", "/status/health_check", "/admin/faultline"]

  # =============================================================================
  # Data Configuration
  # =============================================================================

  # Maximum backtrace lines to store per occurrence
  config.backtrace_lines_limit = 50

  # How long to keep error data in days (nil = forever). Faultline only stores
  # this number; FaultlineCleanupJob (nightly via GoodJob's cron, see
  # config.good_job.cron in config/application.rb) is what deletes occurrences
  # older than this and the groups left empty by it.
  config.retention_days = 90

  # =============================================================================
  # Callbacks (Advanced)
  # =============================================================================

  # Before tracking - return false to skip tracking this error.
  #
  # An unhandled request exception reaches Faultline twice. The Rack middleware
  # (enable_middleware above, innermost in the stack) sees it first and records
  # the request, the signed-in user and the captured locals. It then re-raises,
  # and ActionDispatch::Executor at the top of the stack reports the very same
  # exception to Rails.error with source "application.action_dispatch", which
  # the error subscriber would turn into a second occurrence with no user and
  # no URL -- doubling every count and alert threshold and leaving half the
  # occurrences anonymous. Drop that second report. The subscriber still
  # handles everything the middleware cannot see: background jobs (source
  # "application.active_job" / "good_job") and explicit Rails.error calls.
  config.before_track = lambda { |_exception, context|
    context[:source] != "application.action_dispatch"
  }

  # After tracking - for custom integrations
  # config.after_track = lambda { |error_group, occurrence|
  #   # Example: Send to analytics
  #   Analytics.track("error_occurred", {
  #     exception: error_group.exception_class,
  #     count: error_group.occurrences_count
  #   })
  # }

  # Custom fingerprinting - control how errors are grouped
  # config.custom_fingerprint = lambda { |exception, context|
  #   # Example: Group by feature flag
  #   { extra_components: [context.dig(:custom_data, :feature_flag)] }
  # }

  # =============================================================================
  # Application Performance Monitoring (APM)
  # =============================================================================

  # Enable basic APM to track request performance metrics.
  # Captures response times, database queries, and throughput per endpoint.
  # The dashboard lives at /admin/faultline/performance.
  config.enable_apm = true

  # Sample rate (0.0 to 1.0, 1.0 = every request). Each sampled request costs
  # an extra INSERT (plus span JSON) after the response is sent, so we trace
  # 30% of requests: enough to get meaningful p95s per endpoint without
  # tripling the write load on a small database.
  config.apm_sample_rate = 0.3

  # Paths to ignore for APM (defaults to middleware_ignore_paths if nil).
  # Faultline's own routes are always ignored; the load balancer polls
  # /status/health_check constantly and would swamp the traces.
  config.apm_ignore_paths = ["/assets", "/status/health_check", "/admin/faultline"]

  # How long to keep APM traces (and their profiles) in days. Enforced by
  # FaultlineCleanupJob, which GoodJob's cron runs nightly (see
  # config.good_job.cron in config/application.rb). `rake faultline:apm:cleanup`
  # does the APM half of that by hand.
  config.apm_retention_days = 30

  # --- Span Collection (Waterfall Visualization) ---
  # Capture detailed spans for SQL, HTTP, Redis, and view rendering.
  # When enabled, traces include a waterfall timeline showing each operation.
  # config.apm_capture_spans = true  # default: true when APM enabled

  # --- CPU Profiling (Flame Graphs) ---
  # Enable sampling-based profiling using stackprof for flame graph visualization.
  # Requires: gem 'stackprof' in your Gemfile
  # config.apm_enable_profiling = false  # disabled by default

  # Profile only a sample of requests to minimize overhead (0.0 to 1.0)
  # config.apm_profile_sample_rate = 0.1  # 10% of requests

  # Profiler sampling interval in microseconds (default: 1000 = 1ms)
  # Lower values = more detailed profiles but higher overhead
  # config.apm_profile_interval = 1000

  # Profile mode: :cpu (CPU time), :wall (wall clock), or :object (allocations)
  # config.apm_profile_mode = :cpu
end
