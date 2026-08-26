require 'rails_helper'

RSpec.describe PensiveFacade do
  subject(:facade) { described_class.new }

  let(:email) { 'integration@example.edu' }
  let(:token) { 'pensive-token' }
  let(:assignment_url) do
    'https://www.pensieve.co/teacher/classes/class-123/my-assignments/online/assignment-456/extensions'
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('PENSIEVE_EMAIL').and_return(email)
    allow(ENV).to receive(:[]).with('PENSIEVE_API_TOKEN').and_return(token)
    allow(ENV).to receive(:[]).with('PENSIEVE_ASSIGNMENTS_PATH')
      .and_return('/api/b2s/v1/external-client/assignments')
  end

  describe '.from_user' do
    it 'uses the service account instead of the acting user' do
      expect(described_class.from_user(Object.new)).to be_a(described_class)
    end
  end

  describe '.assignment_url' do
    it 'returns the stored Pensive assignment URL' do
      expect(described_class.assignment_url('https://www.pensieve.co', 'class-123', assignment_url))
        .to eq(assignment_url)
    end

    it 'builds a URL when given a bare assignment id' do
      expect(described_class.assignment_url('https://www.pensieve.co/', 'class-123', 'assignment-456'))
        .to eq('https://www.pensieve.co/teacher/classes/class-123/my-assignments/assignment-456')
    end
  end

  describe '#get_all_assignments' do
    let(:response_body) do
      {
        success: true,
        assignments: [
          {
            assignment_url: assignment_url,
            name: 'Homework 1',
            release_date: '2026-08-01T00:00:00Z',
            due_date: '2026-08-08T07:00:00Z',
            hard_due_date: '2026-08-10T07:00:00Z'
          }
        ]
      }.to_json
    end

    before do
      stub_request(:get, "#{described_class::API_URL}/api/b2s/v1/external-client/assignments")
        .with(
          query: { class_id: 'class-123' },
          headers: { 'Authorization' => "Bearer #{token}" }
        )
        .to_return(status: 200, body: response_body, headers: { 'Content-Type' => 'application/json' })
    end

    it 'maps the assignment-list response to shared assignment objects' do
      assignments = facade.get_all_assignments('class-123')

      expect(assignments.length).to eq(1)
      expect(assignments.first).to be_a(Lmss::Pensive::Assignment)
      expect(assignments.first.id).to eq(assignment_url)
      expect(assignments.first.name).to eq('Homework 1')
      expect(assignments.first.release_date).to eq(Time.zone.parse('2026-08-01T00:00:00Z'))
      expect(assignments.first.due_date).to eq(Time.zone.parse('2026-08-08T07:00:00Z'))
      expect(assignments.first.late_due_date).to eq(Time.zone.parse('2026-08-10T07:00:00Z'))
    end

    it 'requires the configured assignment-list endpoint' do
      allow(ENV).to receive(:[]).with('PENSIEVE_ASSIGNMENTS_PATH').and_return(nil)

      expect { facade.get_all_assignments('class-123') }
        .to raise_error(described_class::PensiveAPIError, /PENSIEVE_ASSIGNMENTS_PATH/)
    end

    it 'rejects unsuccessful payloads' do
      stub_request(:get, "#{described_class::API_URL}/api/b2s/v1/external-client/assignments")
        .with(query: { class_id: 'class-123' })
        .to_return(status: 200, body: { success: false }.to_json)

      expect { facade.get_all_assignments('class-123') }
        .to raise_error(described_class::PensiveAPIError, /could not fetch assignments/)
    end

    it 'rejects assignments without a URL' do
      stub_request(:get, "#{described_class::API_URL}/api/b2s/v1/external-client/assignments")
        .with(query: { class_id: 'class-123' })
        .to_return(
          status: 200,
          body: { success: true, assignments: [ { name: 'Homework 1' } ] }.to_json
        )

      expect { facade.get_all_assignments('class-123') }
        .to raise_error(described_class::PensiveAPIError, /assignment URL is missing/)
    end
  end

  describe '#provision_extension' do
    before do
      stub_request(:post, "#{described_class::API_URL}#{described_class::GRANT_EXTENSION_PATH}")
        .with(
          headers: {
            'Authorization' => "Bearer #{token}",
            'Content-Type' => 'application/json'
          },
          body: {
            assignment_url: assignment_url,
            student_email: 'student@example.edu',
            num_days: 3
          }.to_json
        )
        .to_return(
          status: 200,
          body: { success: true, message: 'Successfully updated extension' }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'posts the legacy Pensive extension payload and returns an override' do
      override = facade.provision_extension(
        'class-123',
        'student@example.edu',
        assignment_url,
        '2026-08-11T07:00:00Z',
        nil,
        extension_days: 3
      )

      expect(override).to be_a(Lmss::Pensive::Override)
      expect(override.student_id).to eq('student@example.edu')
      expect(override.extension_days).to eq(3)
      expect(override.id).to be_nil
    end

    it 'rejects non-positive extension days without making a request' do
      expect do
        facade.provision_extension(
          'class-123', 'student@example.edu', assignment_url, '2026-08-08T07:00:00Z',
          extension_days: 0
        )
      end.to raise_error(described_class::PensiveAPIError, /must be positive/)
    end

    it 'rejects a bare assignment id without making a request' do
      expect do
        facade.provision_extension(
          'class-123', 'student@example.edu', 'assignment-456', '2026-08-11T07:00:00Z',
          extension_days: 3
        )
      end.to raise_error(described_class::PensiveAPIError, /absolute HTTP/)
    end

    it 'raises a facade error when Pensive rejects the request' do
      stub_request(:post, "#{described_class::API_URL}#{described_class::GRANT_EXTENSION_PATH}")
        .to_return(status: 401, body: 'unauthorized')

      expect do
        facade.provision_extension(
          'class-123', 'student@example.edu', assignment_url, '2026-08-11T07:00:00Z',
          extension_days: 3
        )
      end.to raise_error(described_class::PensiveAPIError, /HTTP 401/)
    end
  end

  describe 'configuration' do
    it 'requires an integration email' do
      allow(ENV).to receive(:[]).with('PENSIEVE_EMAIL').and_return(nil)

      expect { described_class.new }
        .to raise_error(described_class::PensiveAPIError, /PENSIEVE_EMAIL/)
    end

    it 'requires an API token' do
      allow(ENV).to receive(:[]).with('PENSIEVE_API_TOKEN').and_return(nil)

      expect { described_class.new }
        .to raise_error(described_class::PensiveAPIError, /PENSIEVE_API_TOKEN/)
    end
  end
end
