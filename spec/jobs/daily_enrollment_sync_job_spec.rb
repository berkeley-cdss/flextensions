require 'rails_helper'

RSpec.describe DailyEnrollmentSyncJob, type: :job do
  describe '#perform' do
    it 'schedules only eligible courses and spreads their syncs across the next hour' do
      first_course = create(:course, :with_staff)
      second_course = create(:course, :with_staff)

      recently_synced = create(:course, :with_staff)
      recently_synced.course_to_lms(CANVAS_LMS_ID)
                     .update!(recent_roster_sync: { synced_at: 1.hour.ago.iso8601 })

      old_course = create(:course, :with_staff)
      old_course.update_column(:created_at, 5.weeks.ago - 1.second) # rubocop:disable Rails/SkipsModelValidations

      create(:course) # No staff member with Canvas credentials.

      scheduled = []
      allow(AutomaticEnrollmentSyncJob).to receive(:set) do |wait:|
        proxy = double
        allow(proxy).to receive(:perform_later) { |course_id| scheduled << [ course_id, wait ] }
        proxy
      end

      expect(described_class.perform_now).to eq(2)
      expect(scheduled).to eq([
        [ first_course.id, 0.0 ],
        [ second_course.id, 30.minutes.to_f ]
      ])
    end

    it 'does not try to divide the spread window when no courses are eligible' do
      expect(AutomaticEnrollmentSyncJob).not_to receive(:set)

      expect(described_class.perform_now).to eq(0)
    end
  end
end
