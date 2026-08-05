# GoodJob runs in-process inside Puma (config.good_job.execution_mode = :async
# in config/environments/production.rb), so no separate `worker` process is
# needed for the single-instance-per-environment setup.
#
# To run a dedicated worker instead, set execution_mode to :external and add:
#   worker: bundle exec good_job start
web: bundle exec rails server -p $PORT
