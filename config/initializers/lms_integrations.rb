# Well-known LMS row ids (see db/seeds.rb and Lms.preload!).
CANVAS_LMS_ID = 1
GRADESCOPE_LMS_ID = 2

# When the app boots, assert that the Canvas LMS row (id 1) exists — creating
# it if necessary — and preload the lms table into memory so requests never
# have to query it. `to_prepare` runs once at boot and again after each code
# reload in development, which re-warms the cache; it does NOT run per request.
#
# The database or the lmss table may not exist yet while running tasks like
# `rails db:create` / `db:migrate` — skip quietly in that case; migrations and
# seeds are responsible for the row then.
Rails.application.config.to_prepare do
  Lms.preload! if Lms.table_exists?
rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished => e
  Rails.logger.warn("Skipping LMS preload (database unavailable): #{e.message}")
end
