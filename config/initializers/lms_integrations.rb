# Ensure all LMS integrations are set up
# TODO: We should deprecate the need for specific LMSs.
Rails.application.config.after_initialize do
  CANVAS_LMS_ID = 1
  GRADESCOPE_LMS_ID = 2

  # Disabled because this initialzer is loaded when doing migrations
  # this casues if the `lmss` table changes.
  # begin
  #   next unless ActiveRecord::Base.connection.table_exists?('lmss')
  #   # Warm the tiny cache.
  # rescue ActiveRecord::NoDatabaseError
  #   # Skip if database doesn't exist
  #   next
  # end
end
