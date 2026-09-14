require 'rails_helper'

RSpec.describe FaultlineCleanupJob, type: :job do
  def create_group(fingerprint:, last_seen_at:)
    Faultline::ErrorGroup.create!(
      fingerprint: fingerprint, exception_class: 'RuntimeError', sanitized_message: 'boom',
      first_seen_at: last_seen_at, last_seen_at: last_seen_at
    )
  end

  def create_occurrence(group, created_at:)
    occurrence = Faultline::ErrorOccurrence.create!(
      error_group: group, exception_class: 'RuntimeError', message: 'boom', created_at: created_at
    )
    Faultline::ErrorContext.create!(error_occurrence: occurrence, key: 'component', value: 'spec')
    occurrence
  end

  def create_trace(created_at:)
    trace = Faultline::RequestTrace.create!(endpoint: 'CoursesController#index', http_method: 'GET', created_at: created_at)
    Faultline::RequestProfile.create!(request_trace: trace, profile_data: '{}')
    trace
  end

  before do
    allow(Faultline.configuration).to receive_messages(retention_days: 90, apm_retention_days: 30)
  end

  it 'deletes error occurrences, their contexts, and emptied groups past the retention window' do
    stale_group = create_group(fingerprint: 'stale', last_seen_at: 100.days.ago)
    create_occurrence(stale_group, created_at: 100.days.ago)

    mixed_group = create_group(fingerprint: 'mixed', last_seen_at: 1.day.ago)
    create_occurrence(mixed_group, created_at: 100.days.ago)
    kept = create_occurrence(mixed_group, created_at: 1.day.ago)

    described_class.perform_now

    expect(Faultline::ErrorGroup.where(id: stale_group.id)).not_to exist
    expect(Faultline::ErrorOccurrence.pluck(:id)).to eq([ kept.id ])
    expect(Faultline::ErrorContext.pluck(:error_occurrence_id)).to eq([ kept.id ])
    expect(mixed_group.reload.occurrences_count).to eq(1)
  end

  it 'keeps a group whose occurrences all aged out but was seen recently' do
    group = create_group(fingerprint: 'recent', last_seen_at: 1.day.ago)
    create_occurrence(group, created_at: 100.days.ago)

    described_class.perform_now

    expect(group.reload.occurrences_count).to eq(0)
  end

  it 'deletes APM traces and profiles past the APM retention window' do
    stale = create_trace(created_at: 31.days.ago)
    fresh = create_trace(created_at: 1.day.ago)

    described_class.perform_now

    expect(Faultline::RequestTrace.pluck(:id)).to eq([ fresh.id ])
    expect(Faultline::RequestProfile.pluck(:request_trace_id)).to eq([ fresh.id ])
    expect(Faultline::RequestTrace.where(id: stale.id)).not_to exist
  end

  it 'leaves error data alone when retention is disabled' do
    allow(Faultline.configuration).to receive(:retention_days).and_return(nil)
    group = create_group(fingerprint: 'forever', last_seen_at: 400.days.ago)
    create_occurrence(group, created_at: 400.days.ago)

    expect(described_class.perform_now).to eq(errors: 0, apm: 0)
    expect(group.reload.occurrences_count).to eq(1)
  end
end
