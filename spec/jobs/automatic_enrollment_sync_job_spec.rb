require 'rails_helper'

RSpec.describe AutomaticEnrollmentSyncJob, type: :job do
  include ActiveJob::TestHelper

  around do |example|
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    example.run
  ensure
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = original_adapter
  end

  describe '#perform' do
    it 'enqueues a full roster sync for a recent course with a Canvas-connected staff user' do
      course = create(:course, :with_staff)
      sync_user = course.staff_user_for_auto_approval

      expect {
        described_class.perform_now(course.id)
      }.to have_enqueued_job(SyncUsersFromCanvasJob).with(course.id, sync_user.id, Enrollment.roles)
    end

    it 'skips a course whose roster was synced less than six hours ago' do
      course = create(:course, :with_staff)
      course.course_to_lms(CANVAS_LMS_ID).update!(recent_roster_sync: { synced_at: 1.hour.ago.iso8601 })

      expect {
        described_class.perform_now(course.id)
      }.not_to have_enqueued_job(SyncUsersFromCanvasJob)
    end

    it 'allows a course whose roster was synced exactly six hours ago' do
      travel_to(Time.zone.local(2026, 8, 25, 4)) do
        course = create(:course, :with_staff)
        course.course_to_lms(CANVAS_LMS_ID).update!(recent_roster_sync: { synced_at: 6.hours.ago.iso8601 })

        expect {
          described_class.perform_now(course.id)
        }.to have_enqueued_job(SyncUsersFromCanvasJob)
      end
    end

    it 'skips a course imported more than five weeks ago' do
      course = create(:course, :with_staff)
      course.update_column(:created_at, 5.weeks.ago - 1.second) # rubocop:disable Rails/SkipsModelValidations

      expect {
        described_class.perform_now(course.id)
      }.not_to have_enqueued_job(SyncUsersFromCanvasJob)
    end

    it 'skips a course with no Canvas-connected staff user' do
      course = create(:course)

      expect {
        described_class.perform_now(course.id)
      }.not_to have_enqueued_job(SyncUsersFromCanvasJob)
    end

    it 'falls back to another staff user when the first Canvas token cannot be refreshed' do
      course = create(:course, :with_staff)
      first_user, second_user = course.staff_users_for_auto_approval.first(2)
      allow(first_user).to receive(:ensure_fresh_canvas_token!).and_return(nil)
      allow(second_user).to receive(:ensure_fresh_canvas_token!).and_return('fresh-token')
      allow(course).to receive(:staff_users_for_auto_approval).and_return([ first_user, second_user ])
      allow(Course).to receive(:find_by).with(id: course.id).and_return(course)

      expect {
        described_class.perform_now(course.id)
      }.to have_enqueued_job(SyncUsersFromCanvasJob).with(course.id, second_user.id, Enrollment.roles)
    end

    it 'exits cleanly when the course was deleted after the sweep' do
      expect {
        described_class.perform_now(-1)
      }.not_to have_enqueued_job(SyncUsersFromCanvasJob)
    end
  end
end
