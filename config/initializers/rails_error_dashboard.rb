# frozen_string_literal: true

RailsErrorDashboard.configure do |config|
  # ============================================================================
  # AUTHENTICATION (Always Required - Cannot Be Disabled)
  # ============================================================================

  # We authenticate against the app's own admin users (see `authenticate_with`
  # below), so the built-in HTTP Basic Auth credentials are not used. They are
  # still set to non-default values so the gem's production validation passes
  # and Basic Auth can never be relied on by accident.
  config.dashboard_username = ENV.fetch("ERROR_DASHBOARD_USER", "flextensions-red")
  config.dashboard_password = ENV.fetch("ERROR_DASHBOARD_PASSWORD", SecureRandom.hex(32))

  # === Custom Authentication (optional) ===
  # Use your app's existing auth instead of HTTP Basic Auth.
  # The lambda runs in controller context (via instance_exec), giving access to
  # warden, session, request, params, cookies, redirect_to, etc.
  # Return truthy to allow access, falsy to deny (403 Forbidden).
  #
  # NOTE: Devise helpers (current_user, authenticate_user!) are NOT available
  # because the engine controller inherits from ActionController::Base, not your
  # app's ApplicationController. Use `warden` directly instead.
  #
  # Devise/Warden example (recommended):
  #   config.authenticate_with = -> { warden.authenticated? }
  #
  # Warden with redirect to login:
  #   config.authenticate_with = -> {
  #     if warden.authenticated?
  #       true
  #     else
  #       redirect_to main_app.new_user_session_path, allow_other_host: true
  #     end
  #   }
  #
  # Session-based example:
  #   config.authenticate_with = -> { session[:dashboard_admin] == true }
  #
  # When nil (default), HTTP Basic Auth above is used instead.
  #
  # Flextensions integration: gate the dashboard behind the same admin users
  # that protect Blazer (see ApplicationController#require_admin). The engine
  # controller inherits from ActionController::Base, so `current_user` is not
  # available here — we resolve the logged-in user from the session the same way
  # ApplicationController#current_user does and require the `admin` flag.
  config.authenticate_with = lambda do
    user = User.find_by(canvas_uid: session[:user_id])
    user.present? && user.admin?
  end

  # ============================================================================
  # CORE FEATURES (Always Enabled)
  # ============================================================================

  # Error capture via middleware and Rails.error subscriber
  config.enable_middleware = true
  config.enable_error_subscriber = true

  # User model for error associations
  config.user_model = "User"

  # Error retention policy (days to keep errors before automatic deletion)
  # Set to nil to keep errors forever (not recommended for production)
  # Run cleanup manually: rails error_dashboard:retention_cleanup
  # Or schedule the job: RailsErrorDashboard::RetentionCleanupJob.perform_later
  config.retention_days = 90

  # ============================================================================
  # NOTIFICATION SETTINGS
  # ============================================================================
  # Configure which notification channels you want to use.
  # You can enable/disable any of these at any time by changing true/false.

  # Slack Notifications - DISABLED
  # To enable: Set config.enable_slack_notifications = true and configure webhook URL
  config.enable_slack_notifications = false
  # config.slack_webhook_url = ENV["SLACK_WEBHOOK_URL"]

  # Email Notifications - DISABLED
  # To enable: Set config.enable_email_notifications = true and configure recipients
  config.enable_email_notifications = false
  # config.notification_email_recipients = ENV.fetch("ERROR_NOTIFICATION_EMAILS", "").split(",").map(&:strip)
  # config.notification_email_from = ENV.fetch("ERROR_NOTIFICATION_FROM", "errors@example.com")

  # Discord Notifications - DISABLED
  # To enable: Set config.enable_discord_notifications = true and configure webhook URL
  config.enable_discord_notifications = false
  # config.discord_webhook_url = ENV["DISCORD_WEBHOOK_URL"]

  # PagerDuty Integration - DISABLED
  # To enable: Set config.enable_pagerduty_notifications = true and configure integration key
  config.enable_pagerduty_notifications = false
  # config.pagerduty_integration_key = ENV["PAGERDUTY_INTEGRATION_KEY"]

  # Generic Webhook Notifications - DISABLED
  # To enable: Set config.enable_webhook_notifications = true and configure webhook URLs
  config.enable_webhook_notifications = false
  # config.webhook_urls = ENV.fetch("WEBHOOK_URLS", "").split(",").map(&:strip).reject(&:empty?)

  # Dashboard base URL (used in notification links)
  config.dashboard_base_url = ENV["DASHBOARD_BASE_URL"]

  # ============================================================================
  # PERFORMANCE & SCALABILITY
  # ============================================================================

  # Async Error Logging - ENABLED
  # Errors are logged in background jobs — zero impact on request response time.
  # Default adapter is :async (Rails built-in, no extra infrastructure needed).
  # Swap to :sidekiq or :solid_queue when you have a background worker running.
  config.async_logging = true
  config.async_adapter = :async  # Options: :async (built-in), :sidekiq, :solid_queue
  # To disable: Set config.async_logging = false

  # Backtrace size limiting (100 lines is industry standard: Rollbar, Airbrake, Bugsnag)
  config.max_backtrace_lines = 100

  # Error Sampling - DISABLED
  # All errors are logged (100% sampling rate).
  # To enable: Set config.sampling_rate < 1.0 (e.g., 0.5 for 50%, 0.1 for 10%)
  config.sampling_rate = 1.0

  # Ignored exceptions (skip logging these)
  # config.ignored_exceptions = [
  #   "ActionController::RoutingError",
  #   "ActionController::InvalidAuthenticityToken",
  #   /^ActiveRecord::RecordNotFound/
  # ]

  # ============================================================================
  # DATABASE CONFIGURATION
  # ============================================================================

  # Separate Error Database - DISABLED
  # Errors are stored in your main application database.
  # To enable: Set config.use_separate_database = true and configure database.yml
  # See https://github.com/AnjanJ/rails_error_dashboard/blob/main/docs/guides/DATABASE_OPTIONS.md
  config.use_separate_database = false
  # config.database = :error_dashboard

  # ============================================================================
  # ADVANCED ANALYTICS
  # ============================================================================

  # Baseline Anomaly Alerts - DISABLED
  # To enable: Set config.enable_baseline_alerts = true
  config.enable_baseline_alerts = false
  # config.baseline_alert_threshold_std_devs = 2.0
  # config.baseline_alert_severities = [ :critical, :high ]
  # config.baseline_alert_cooldown_minutes = 120

  # Fuzzy Error Matching - DISABLED
  # To enable: Set config.enable_similar_errors = true
  config.enable_similar_errors = false

  # Co-occurring Errors - DISABLED
  # To enable: Set config.enable_co_occurring_errors = true
  config.enable_co_occurring_errors = false

  # Error Cascade Detection - DISABLED
  # To enable: Set config.enable_error_cascades = true
  config.enable_error_cascades = false

  # Error Correlation Analysis - DISABLED
  # To enable: Set config.enable_error_correlation = true
  config.enable_error_correlation = false

  # Platform Comparison - DISABLED
  # To enable: Set config.enable_platform_comparison = true
  config.enable_platform_comparison = false

  # Occurrence Pattern Detection - DISABLED
  # To enable: Set config.enable_occurrence_patterns = true
  config.enable_occurrence_patterns = false

  # ============================================================================
  # DEVELOPER TOOLS (NEW!)
  # ============================================================================

  # Source Code Integration - DISABLED (NEW!)
  # To enable: Set config.enable_source_code_integration = true
  config.enable_source_code_integration = false

  # Git Blame Integration - DISABLED (NEW!)
  # To enable: Set config.enable_git_blame = true (requires Git installed)
  config.enable_git_blame = false

  # Breadcrumbs - DISABLED
  # To enable: Set config.enable_breadcrumbs = true
  config.enable_breadcrumbs = false
  # config.breadcrumb_buffer_size = 40

  # N+1 Query Detection (analyzes SQL breadcrumbs at display time)
  # Flags repeated query patterns that suggest missing eager loading
  config.enable_n_plus_one_detection = true
  config.n_plus_one_threshold = 3  # Min repetitions to flag (min: 2)

  # System Health Snapshot - DISABLED (NEW!)
  # To enable: Set config.enable_system_health = true
  config.enable_system_health = false

  # Swallowed Exception Detection - DISABLED
  # Requires Ruby 3.3+ (TracePoint(:rescue) not available before 3.3)
  # To enable: Set config.detect_swallowed_exceptions = true
  config.detect_swallowed_exceptions = false
  # config.swallowed_exception_threshold = 0.95

  # Diagnostic Dump - DISABLED
  # On-demand system state snapshot (rake task + dashboard page)
  # To enable: Set config.enable_diagnostic_dump = true
  config.enable_diagnostic_dump = false

  # Process Crash Capture - DISABLED
  # Captures fatal crashes via at_exit hook (written to disk, imported on next boot)
  # To enable: Set config.enable_crash_capture = true
  config.enable_crash_capture = false
  # config.crash_capture_path = "/tmp/my_app_crashes"

  # Repository settings (auto-detected from git remote, optional override)
  # config.repository_url = ENV["REPOSITORY_URL"]  # e.g., "https://github.com/user/repo"
  # config.repository_branch = ENV.fetch("REPOSITORY_BRANCH", "main")  # Default branch

  # ============================================================================
  # INTERNAL LOGGING (Silent by Default)
  # ============================================================================
  # Rails Error Dashboard logging is SILENT by default to keep your logs clean.
  # Enable only for debugging gem issues or troubleshooting setup.

  # Enable internal logging (default: false - silent)
  config.enable_internal_logging = false

  # Log level (default: :silent)
  # Options: :debug, :info, :warn, :error, :silent
  config.log_level = :silent

  # Example: Enable verbose logging for debugging
  # config.enable_internal_logging = true
  # config.log_level = :debug

  # Example: Log only errors (troubleshooting)
  # config.enable_internal_logging = true
  # config.log_level = :error

  # ============================================================================
  # ADDITIONAL CONFIGURATION
  # ============================================================================

  # Custom severity rules (override automatic severity classification)
  # config.custom_severity_rules = {
  #   "PaymentError" => :critical,
  #   "ValidationError" => :low
  # }

  # Enhanced metrics (optional)
  config.app_version = ENV["APP_VERSION"]
  config.git_sha = ENV["GIT_SHA"]
  # config.total_users_for_impact = 10000  # For user impact % calculation

  # Git repository URL for clickable commit links and issue tracking
  # Examples:
  #   GitHub: "https://github.com/username/repo"
  #   GitLab: "https://gitlab.com/username/repo"
  #   Codeberg: "https://codeberg.org/username/repo"
  # config.git_repository_url = ENV["GIT_REPOSITORY_URL"]

  # ============================================================================
  # AI HELP (OpenAI / Anthropic)
  # ============================================================================
  #
  # When provider and API key are configured, error detail pages show an
  # "AI Help" drawer where dashboard users can ask questions about the current
  # error. Error details, backtrace, and related dashboard context are sent to
  # the configured provider.
  #
  # OpenAI uses the Responses API by default and supports GPT-5 and GPT-4 family
  # models such as "gpt-5" and "gpt-4.1". Set llm_openai_endpoint to
  # :chat_completions only if you need the older Chat Completions endpoint.
  #
  # config.llm_provider = :openai
  # config.llm_api_key = -> { Rails.application.credentials.dig(:openai, :api_key) }
  # config.llm_model = "gpt-5"
  # config.llm_openai_endpoint = :auto # :auto, :responses, or :chat_completions
  #
  # config.llm_provider = :anthropic
  # config.llm_api_key = -> { Rails.application.credentials.dig(:anthropic, :api_key) }
  # config.llm_model = "claude-sonnet-4-20250514"
  #
  # Shared options:
  # config.llm_timeout_seconds = 30
  # config.llm_max_output_tokens = 900
  # config.llm_system_prompt = "Prefer concise answers with file-level next steps."

  # ============================================================================
  # OPENTELEMETRY EXPORT (OUTBOUND)
  # ============================================================================
  #
  # Emit gem operations as OpenTelemetry spans so the host's existing
  # Datadog / Honeycomb / Jaeger / Grafana Tempo pipeline gets a trace
  # of every error capture. Useful for:
  #   - Auditing "when did this error get captured?" against deploy events
  #   - Measuring how much time the gem spends in the capture path
  #   - Proving the <5ms host-safety budget from operator dashboards
  #
  # Emits four spans per error capture:
  #   rails_error_dashboard.capture_error           — parent, wraps everything
  #   rails_error_dashboard.breadcrumb_collection   — buffer drain (~µs)
  #   rails_error_dashboard.system_health_snapshot  — GC.stat etc. (<1ms)
  #   rails_error_dashboard.notification_dispatch   — Slack/email enqueue
  #
  # Disabled by default. Requires the host app to already run OpenTelemetry
  # (the gem does NOT add an opentelemetry-* runtime dependency). When OTel
  # is absent, every span call is a zero-overhead no-op.
  #
  # config.enable_otel_export = true
  # config.otel_service_name = "my-app"  # Falls back to application_name when nil
  #
  # Per-span opt-out: pass any subset to disable individual span kinds
  # without code changes. Useful when e.g. notification dispatch is slow due
  # to outbound HTTP and you don't want it polluting your trace dashboards.
  #
  # config.otel_spans = [:capture, :breadcrumbs, :health, :notifications]  # all (default)
  # config.otel_spans = [:capture]                                          # parent only
  # config.otel_spans = [:capture, :health]                                 # parent + health
  #
  # No PII or request bodies in span attributes — just metadata + timing.
  # Safe to enable on production OTel pipelines.

  # ============================================================================
  # STORM PROTECTION (circuit breaker + adaptive sampling) — ON by default
  # ============================================================================
  #
  # When the error rate spikes (bad deploy, dependency outage), storm
  # protection limits the gem's own database writes so it never amplifies
  # the incident. Occurrences are ALWAYS counted exactly — only per-event
  # detail (context payloads, occurrence rows) is sampled under load.
  #
  # How it degrades, in order:
  #   1. Per-fingerprint cap: past N/min, context is shed, then rows sampled
  #   2. Global breaker: shedding (context off) → open (count-only mode)
  #   3. Per-error notifications replaced by ONE "storm in progress" message
  #   4. Counts reconciled onto error records every flush interval
  #
  # All thresholds are PER PROCESS (each Puma worker runs its own breaker).
  #
  # config.enable_storm_protection = true
  # config.storm_fingerprint_full_per_minute = 30   # full-fidelity captures per fingerprint/min
  # config.storm_occurrence_sample_keep_every = 10  # past the cap, keep every Nth occurrence
  # config.storm_shedding_threshold_per_second = 10 # global rate entering shedding state
  # config.storm_open_threshold_per_second = 50     # global rate opening the breaker (count-only)
  # config.storm_cooldown_seconds = 60              # open → half-open probe delay
  # config.storm_notification = true                # one notification per storm episode
  #
  # Always-on issue cap (a storm of NEW critical errors must not open
  # hundreds of GitHub/Linear issues):
  # config.auto_issue_rate_limit_count = 5
  # config.auto_issue_rate_limit_window_minutes = 10
  #
  # Calm-weather context economy: an error seen 1000x/day doesn't need 1000
  # breadcrumb trails. After N full-context captures per fingerprint per day,
  # context is kept every Mth time (occurrence rows are unaffected):
  # config.context_sampling_threshold_per_day = 25
  # config.context_sampling_keep_every = 10

  # ============================================================================
  # ISSUE TRACKING (GitHub / GitLab / Codeberg / Linear)
  # ============================================================================
  #
  # One switch enables everything: issue creation, auto-create on first
  # occurrence, lifecycle sync (resolve → close, reopen → reopen), platform
  # state mirroring (status, assignees, labels), and comment display.
  #
  # IMPORTANT: When enabled, the dashboard shows platform state instead of
  # internal workflow controls:
  #   - "Mark as Resolved" → replaced by issue open/closed from platform
  #   - Workflow Status → issue state from platform
  #   - Assigned To → assignees from platform (with avatars)
  #   - Priority → labels from platform (with colors)
  #   - Snooze and Mute remain (no platform equivalent)
  #
  # Setup (GitHub/GitLab/Codeberg):
  #   1. Create a RED bot account on GitHub/GitLab/Codeberg
  #   2. Generate a token and set RED_BOT_TOKEN env var
  #   3. Set git_repository_url above (already used for source code linking)
  #   4. Enable:
  #
  # config.enable_issue_tracking = true
  # config.issue_tracker_token = ENV["RED_BOT_TOKEN"]
  #
  # Setup (Linear):
  #   Linear is not a git forge, so it cannot be auto-detected from
  #   git_repository_url — set provider and team key explicitly. Issues are
  #   created in the team matching the key (e.g. "ENG" for ENG-123 issues).
  #   Generate a personal API key under Settings > Security & access.
  #
  # config.enable_issue_tracking = true
  # config.issue_tracker_provider = :linear
  # config.issue_tracker_repo = "ENG"                              # Linear team key
  # config.issue_tracker_token = ENV["RED_BOT_TOKEN"]              # lin_api_... key
  #
  # Optional overrides:
  # config.issue_tracker_labels = ["bug"]                          # Labels added to new issues
  # config.issue_tracker_auto_create_severities = [:critical, :high]  # Auto-create threshold
  # config.issue_webhook_secret = ENV["ISSUE_WEBHOOK_SECRET"]      # Enables two-way webhook sync
end
