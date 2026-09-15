# Enforces Faultline's two retention settings, neither of which the gem
# enforces on its own (config/initializers/faultline.rb):
#
#   * apm_retention_days -- request traces and the CPU profiles attached to
#     them. The gem ships `rake faultline:apm:cleanup` for this; the job calls
#     the same model methods.
#   * retention_days -- error occurrences and their context rows. The gem only
#     stores this number and leaves the deletion to "a cron job or Sidekiq
#     scheduler", so it is done here.
#
# GoodJob's cron runs this nightly (config.good_job.cron in
# config/application.rb). Without it both sets of tables grow without bound.
class FaultlineCleanupJob < ApplicationJob
  queue_as :default

  def perform
    traces = cleanup_apm
    occurrences = cleanup_errors

    Rails.logger.info(
      "[Faultline] Cleanup removed #{traces} APM traces and #{occurrences} error occurrences"
    )

    { traces: traces, occurrences: occurrences }
  end

  private

  def cleanup_apm
    return 0 unless Faultline::RequestTrace.table_exists?

    Faultline::RequestProfile.cleanup! if Faultline::RequestProfile.table_exists?
    Faultline::RequestTrace.cleanup!
  end

  # Occurrences are deleted with delete_all, which skips ActiveRecord
  # callbacks, so the context rows (no ON DELETE CASCADE) are removed first
  # and the groups' occurrences_count counter cache is recomputed afterwards.
  # A group whose occurrences have all aged out is removed too, unless it was
  # marked "ignored" -- keeping it is what stops a recurrence from opening a
  # fresh, alerting group.
  def cleanup_errors
    retention_days = Faultline.configuration.retention_days
    return 0 if retention_days.nil? # nil means keep forever

    cutoff = retention_days.days.ago
    stale = Faultline::ErrorOccurrence.where(created_at: ...cutoff)

    Faultline::ErrorContext.where(error_occurrence_id: stale.select(:id)).delete_all
    deleted = stale.delete_all
    return 0 if deleted.zero?

    # One statement recomputes every counter; there are no validations on
    # ErrorGroup that a per-record save would add.
    Faultline::ErrorGroup.update_all(<<~SQL.squish) # rubocop:disable Rails/SkipsModelValidations
      occurrences_count = (
        SELECT COUNT(*) FROM faultline_error_occurrences
        WHERE faultline_error_occurrences.error_group_id = faultline_error_groups.id
      )
    SQL

    Faultline::ErrorGroup.where(occurrences_count: 0)
                         .where(last_seen_at: ...cutoff)
                         .where.not(status: 'ignored')
                         .delete_all

    deleted
  end
end
