# Prunes Faultline's error and APM tables. Faultline defines the retention
# settings (retention_days for errors, apm_retention_days for request traces)
# but only ships a rake task for the APM half and nothing for errors, so
# without this job both grow forever. Scheduled by GoodJob cron in
# config/application.rb.
class FaultlineCleanupJob < ApplicationJob
  queue_as :default

  def perform
    deleted = { errors: cleanup_errors, apm: cleanup_apm }
    Rails.logger.info "Faultline cleanup: #{deleted.to_json}"
    deleted
  end

  private

  # Deletes error occurrences (and their context rows) older than
  # retention_days, corrects the occurrence counters on their groups, then
  # deletes groups that no longer have any occurrences and were last seen
  # before the cutoff. Groups seen more recently keep their history.
  def cleanup_errors
    retention_days = Faultline.configuration.retention_days
    return 0 unless retention_days

    cutoff = retention_days.days.ago
    stale = Faultline::ErrorOccurrence.where(created_at: ...cutoff)
    group_ids = stale.distinct.pluck(:error_group_id)

    Faultline::ErrorContext.where(error_occurrence_id: stale.select(:id)).delete_all
    occurrences_deleted = stale.delete_all

    groups = Faultline::ErrorGroup.where(id: group_ids)
    groups.update_all(<<~SQL.squish) # rubocop:disable Rails/SkipsModelValidations -- counter cache recompute
      occurrences_count = (
        SELECT COUNT(*) FROM faultline_error_occurrences
        WHERE faultline_error_occurrences.error_group_id = faultline_error_groups.id
      )
    SQL
    groups.where(occurrences_count: 0).where(last_seen_at: ...cutoff).delete_all

    occurrences_deleted
  end

  # Mirrors `rake faultline:apm:cleanup`: profiles first, since they
  # reference traces.
  def cleanup_apm
    return 0 unless Faultline::RequestTrace.table_exists_for_apm?

    Faultline::RequestProfile.cleanup!
    Faultline::RequestTrace.cleanup!
  end
end
