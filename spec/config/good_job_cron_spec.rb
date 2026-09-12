require 'rails_helper'

# Nothing enqueues PendingRequestsNotificationJob except GoodJob's cron, so the
# schedule is as much a part of the feature as the job itself.
RSpec.describe 'GoodJob cron schedule' do # rubocop:disable RSpec/DescribeClass
  let(:cron) { Rails.application.config.good_job[:cron] }
  let(:digest_entries) { cron.select { |_key, entry| entry[:class] == 'PendingRequestsNotificationJob' } }
  let(:enrollment_sync_entry) { cron.fetch(:daily_enrollment_sync) }

  it 'schedules a digest for every frequency a course can choose' do
    frequencies = digest_entries.values.map { |entry| entry[:args].first }

    expect(frequencies).to match_array(CourseSettings::VALID_NOTIFICATION_FREQUENCIES)
  end

  it 'uses schedules GoodJob can parse' do
    expect { GoodJob.configuration.cron_entries }.not_to raise_error
  end

  it 'runs the hourly digest once per hour' do
    occurrences = Fugit.parse_cron(cron[:pending_digests_hourly][:cron])
                       .within(Time.utc(2026, 1, 1, 7, 59)..Time.utc(2026, 1, 2, 7, 59))

    expect(occurrences.size).to eq(24)
  end

  it 'runs the daily digest at 4:00 PM Pacific' do
    occurrence = Fugit.parse_cron(cron[:pending_digests_daily][:cron]).next_time(Time.utc(2026, 1, 1))

    expect(occurrence.to_t.in_time_zone('America/Los_Angeles').strftime('%H:%M')).to eq('16:00')
  end

  it 'runs the weekly digest on Thursdays at 4:00 PM Pacific, as the settings page promises' do
    occurrence = Fugit.parse_cron(cron[:pending_digests_weekly][:cron]).next_time(Time.utc(2026, 1, 1))

    expect(occurrence.to_t.in_time_zone('America/Los_Angeles').strftime('%A %H:%M')).to eq('Thursday 16:00')
  end

  it 'runs the enrollment sync sweep daily at 3:00 AM Pacific' do
    schedule = Fugit.parse_cron(enrollment_sync_entry[:cron])
    occurrences = schedule.within(Time.utc(2026, 1, 1, 7, 59)..Time.utc(2026, 1, 2, 7, 59))

    expect(enrollment_sync_entry[:class]).to eq('DailyEnrollmentSyncJob')
    expect(occurrences.size).to eq(1)
    expect(occurrences.first.to_t.in_time_zone('America/Los_Angeles').strftime('%H:%M')).to eq('03:00')
  end
end
