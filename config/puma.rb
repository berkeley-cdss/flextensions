# Loaded by `rails server` locally and by the Procfile on Elastic Beanstalk.
# Local: WEB_CONCURRENCY unset → 0 workers → `single` block.
# EB:    WEB_CONCURRENCY=2   → 2 workers → `cluster` block.
#
# Per worker process:  AR pool >= RAILS_MAX_THREADS + GOOD_JOB_MAX_THREADS + 1
# database.yml derives the pool from the same env vars — keep them in sync.

max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
min_threads_count = ENV.fetch("RAILS_MIN_THREADS", max_threads_count).to_i
threads min_threads_count, max_threads_count

environment ENV.fetch("RAILS_ENV", "development")
workers ENV.fetch("WEB_CONCURRENCY", 0).to_i

single do
  # Local development / test
  port ENV.fetch("PORT", 3000)
  plugin :tmp_restart            # bin/rails restart
end

cluster do
  # Elastic Beanstalk / EC2
  directory "/var/app/current"
  preload_app!
  worker_timeout 120             # default 60; nightly AIDE run was killing workers
  bind "unix:///var/run/puma/my_app.sock"   # EB nginx proxies to this socket
  stdout_redirect "/var/log/puma/puma.log", "/var/log/puma/puma.log", true
end

# Thread backtraces only if a graceful stop escalates to a forced one.
shutdown_debug on_force: true
force_shutdown_after 30

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
