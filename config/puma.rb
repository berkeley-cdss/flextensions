# Loaded by `rails server` locally and in the Docker image, and by the Procfile
# (`bundle exec puma -C config/puma.rb`) on Elastic Beanstalk.
#
# Where Puma listens depends on *where it is running*, never on how many
# workers it has. EB's nginx only proxies to the Unix socket below, so the
# socket bind must apply in single mode too: an EB environment without
# WEB_CONCURRENCY set otherwise boots one process on TCP 3000, nginx answers
# 502, the health check fails and EB rolls the deployment back.
#
# Per worker process:  AR pool >= RAILS_MAX_THREADS + GOOD_JOB_MAX_THREADS + 1
# database.yml derives the pool from the same env vars — keep them in sync.

max_threads_count = ENV.fetch('RAILS_MAX_THREADS', 5).to_i
min_threads_count = ENV.fetch('RAILS_MIN_THREADS', max_threads_count).to_i
threads min_threads_count, max_threads_count

rails_env = ENV.fetch('RAILS_ENV', 'development')
environment rails_env

# The Ruby platform installs its tooling here; dev machines, CI and the Docker
# image do not have it.
on_elastic_beanstalk = File.directory?('/opt/elasticbeanstalk')

if on_elastic_beanstalk
  directory '/var/app/current'
  bind 'unix:///var/run/puma/my_app.sock'   # EB nginx proxies to this socket
  stdout_redirect '/var/log/puma/puma.log', '/var/log/puma/puma.log', true
else
  port ENV.fetch('PORT', 3000)
end

# WEB_CONCURRENCY sets the worker count; 0 runs a single process. Until it is
# set as an EB environment property, production and staging default to 2
# workers and everything else to a single process.
default_workers = %w[production staging].include?(rails_env) ? 2 : 0
workers ENV.fetch('WEB_CONCURRENCY', default_workers).to_i

single do
  plugin :tmp_restart            # bin/rails restart
end

cluster do
  preload_app!
  worker_timeout 120             # default 60; nightly AIDE run was killing workers

  # GoodJob runs in-process (:async, see config/environments/production.rb).
  # With preload_app! its thread pool starts in the master before the fork,
  # and threads do not survive fork, so each worker would inherit a capsule
  # with no running threads. Per GoodJob's Puma guidance: stop before forking,
  # restart in each worker, stop again when a worker exits.
  before_fork { GoodJob.shutdown if defined?(GoodJob) }
  before_worker_boot { GoodJob.restart if defined?(GoodJob) }
  before_worker_shutdown { GoodJob.shutdown if defined?(GoodJob) }
end

# Thread backtraces only if a graceful stop escalates to a forced one.
shutdown_debug on_force: true
force_shutdown_after 30

pidfile ENV['PIDFILE'] if ENV['PIDFILE']
