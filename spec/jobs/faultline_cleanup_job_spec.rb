require 'rails_helper'

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe FaultlineCleanupJob do
  let(:error_retention) { Faultline.configuration.retention_days.days }
  let(:apm_retention) { Faultline.configuration.apm_retention_days.days }

  def create_trace(created_at)
    Faultline::RequestTrace.create!(
      endpoint: 'CoursesController#index', http_method: 'GET', path: '/courses',
      status: 200, duration_ms: 12.5, created_at: created_at
    )
  end

  def create_group(last_seen_at:, status: 'unresolved')
    Faultline::ErrorGroup.create!(
      exception_class: 'RuntimeError', sanitized_message: 'boom', fingerprint: SecureRandom.hex,
      first_seen_at: last_seen_at, last_seen_at: last_seen_at, status: status
    )
  end

  def create_occurrence(group, created_at, context: nil)
    occurrence = Faultline::ErrorOccurrence.create!(
      error_group: group, exception_class: 'RuntimeError', message: 'boom', created_at: created_at
    )
    occurrence.error_contexts.create!(key: 'canvas_uid', value: '123') if context
    occurrence
  end

  describe 'APM traces' do
    it 'deletes traces and their profiles older than apm_retention_days' do
      stale = create_trace(apm_retention.ago - 1.day)
      Faultline::RequestProfile.create!(request_trace: stale, profile_data: '{}', samples: 0)
      fresh = create_trace(apm_retention.ago + 1.day)
      kept = Faultline::RequestProfile.create!(request_trace: fresh, profile_data: '{}', samples: 0)

      expect(described_class.perform_now[:traces]).to eq(1)

      expect(Faultline::RequestTrace.pluck(:id)).to eq([ fresh.id ])
      expect(Faultline::RequestProfile.pluck(:id)).to eq([ kept.id ])
    end
  end

  describe 'error occurrences' do
    it 'deletes occurrences (and their context rows) older than retention_days' do
      group = create_group(last_seen_at: 1.hour.ago)
      stale = create_occurrence(group, error_retention.ago - 1.day, context: true)
      fresh = create_occurrence(group, 1.hour.ago, context: true)

      expect(described_class.perform_now[:occurrences]).to eq(1)

      expect(Faultline::ErrorOccurrence.pluck(:id)).to eq([ fresh.id ])
      expect(Faultline::ErrorContext.pluck(:error_occurrence_id)).to eq([ fresh.id ])
      expect(Faultline::ErrorOccurrence.exists?(stale.id)).to be false
    end

    it 'recomputes the occurrences_count counter cache on groups that lost occurrences' do
      group = create_group(last_seen_at: 1.hour.ago)
      create_occurrence(group, error_retention.ago - 2.days)
      create_occurrence(group, error_retention.ago - 1.day)
      create_occurrence(group, 1.hour.ago)
      expect(group.reload.occurrences_count).to eq(3)

      described_class.perform_now

      expect(group.reload.occurrences_count).to eq(1)
    end

    it 'removes groups whose occurrences have all aged out' do
      stale_group = create_group(last_seen_at: error_retention.ago - 1.day)
      create_occurrence(stale_group, error_retention.ago - 1.day)
      live_group = create_group(last_seen_at: 1.hour.ago)
      create_occurrence(live_group, 1.hour.ago)

      described_class.perform_now

      expect(Faultline::ErrorGroup.pluck(:id)).to eq([ live_group.id ])
    end

    it 'keeps empty groups that were marked ignored so a recurrence stays ignored' do
      ignored = create_group(last_seen_at: error_retention.ago - 1.day, status: 'ignored')
      create_occurrence(ignored, error_retention.ago - 1.day)

      described_class.perform_now

      expect(Faultline::ErrorGroup.exists?(ignored.id)).to be true
      expect(ignored.reload.occurrences_count).to eq(0)
    end

    it 'keeps everything when retention_days is nil' do
      allow(Faultline.configuration).to receive(:retention_days).and_return(nil)
      group = create_group(last_seen_at: 1.year.ago)
      create_occurrence(group, 1.year.ago)

      expect { described_class.perform_now }.not_to change(Faultline::ErrorOccurrence, :count)
    end
  end

  it 'is a no-op when nothing has aged out' do
    create_trace(1.hour.ago)
    create_occurrence(create_group(last_seen_at: 1.hour.ago), 1.hour.ago)

    expect { described_class.perform_now }
      .to not_change(Faultline::RequestTrace, :count)
      .and not_change(Faultline::ErrorOccurrence, :count)
      .and not_change(Faultline::ErrorGroup, :count)
  end
end
