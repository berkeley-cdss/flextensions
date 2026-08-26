require 'rails_helper'

describe PensieveFacade do
  let(:facade) { described_class.new }
  let(:course_url) { 'https://www.pensieve.co/courses/123456' }
  let(:assignment_url) { 'https://www.pensieve.co/assignments/789012' }
  let(:student_email) { 'student@example.com' }
  let(:mock_client) { instance_double(Lmss::Pensieve::Client) }
  let(:api_token) { 'test-pensieve-token' }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('PENSIEVE_API_TOKEN').and_return(api_token)
  end

  describe '.from_user' do
    it 'returns a new instance without requiring a user' do
      expect(described_class.from_user).to be_a(described_class)
    end

    it 'ignores the user parameter as it is for compatibility' do
      expect(described_class.from_user(Object.new)).to be_a(described_class)
    end
  end

  describe '.assignment_url' do
    it 'returns the external assignment id, which is already a URL' do
      expect(described_class.assignment_url('https://www.pensieve.co', course_url, assignment_url))
        .to eq(assignment_url)
    end
  end

  describe '#get_all_assignments' do
    let(:assignments_data) do
      [
        {
          'url' => assignment_url,
          'name' => 'Homework 1',
          'release_date' => '2026-08-01T00:00:00Z',
          'due_date' => '2026-08-30T23:59:59Z',
          'late_due_date' => '2026-09-01T23:59:59Z'
        },
        {
          'assignment_url' => 'https://www.pensieve.co/assignments/345678',
          'title' => 'Homework 2',
          'due_date' => '2026-09-15T23:59:59Z'
        }
      ]
    end

    before do
      allow(Lmss::Pensieve::Client).to receive(:new).and_return(mock_client)
    end

    it 'builds the client with the configured API token' do
      allow(mock_client).to receive(:list_assignments).and_return([])
      expect(Lmss::Pensieve::Client).to receive(:new).with(api_token)
      facade.get_all_assignments(course_url)
    end

    it 'returns an array of Assignment objects' do
      allow(mock_client).to receive(:list_assignments).with(course_url).and_return(assignments_data)
      result = facade.get_all_assignments(course_url)
      expect(result).to all(be_a(Lmss::Pensieve::Assignment))
      expect(result.length).to eq(2)
    end

    it 'correctly parses assignment data' do
      allow(mock_client).to receive(:list_assignments).and_return(assignments_data)
      result = facade.get_all_assignments(course_url)
      expect(result.first.id).to eq(assignment_url)
      expect(result.first.name).to eq('Homework 1')
      expect(result.first.due_date).to eq('2026-08-30T23:59:59Z')
      expect(result.last.id).to eq('https://www.pensieve.co/assignments/345678')
      expect(result.last.name).to eq('Homework 2')
      expect(result.last.release_date).to be_nil
    end

    it 'logs and re-raises authentication errors' do
      allow(mock_client).to receive(:list_assignments).and_raise(Lmss::Pensieve::AuthenticationError, 'bad token')
      expect(Rails.logger).to receive(:error).with(/Pensieve authentication failed: bad token/)
      expect { facade.get_all_assignments(course_url) }.to raise_error(Lmss::Pensieve::AuthenticationError)
    end

    it 'logs and returns an empty array on general errors' do
      allow(mock_client).to receive(:list_assignments).and_raise(StandardError, 'Network error')
      expect(Rails.logger).to receive(:error).with(/Failed to fetch Pensieve assignments: Network error/)
      expect(facade.get_all_assignments(course_url)).to eq([])
    end
  end

  describe '#get_assignment_overrides' do
    it 'returns an empty array because Pensieve cannot read extensions back' do
      expect(facade.get_assignment_overrides(course_url, assignment_url)).to eq([])
    end
  end

  describe '#provision_extension' do
    let(:pensieve_lms) { Lms.find_or_create_by!(id: PENSIEVE_LMS_ID, lms_name: 'Pensieve') }
    let(:course) { create(:course) }
    let(:course_to_lms) do
      create(:course_to_lms, course: course, lms: pensieve_lms, external_course_id: course_url)
    end
    let(:new_due_date) { '2026-09-02T23:59:00Z' }

    before do
      create(:assignment,
             course_to_lms: course_to_lms,
             external_assignment_id: assignment_url,
             due_date: Time.zone.parse('2026-08-30T23:59:00Z'))
      allow(Lmss::Pensieve::Client).to receive(:new).and_return(mock_client)
    end

    it 'grants the extension with the number of days past the original deadline' do
      expect(mock_client).to receive(:grant_extension).with(
        assignment_url: assignment_url,
        student_email: student_email,
        num_days: 3
      ).and_return({ 'success' => true })

      facade.provision_extension(course_url, student_email, assignment_url, new_due_date)
    end

    it 'returns an override carrying the student and new due date' do
      allow(mock_client).to receive(:grant_extension).and_return({ 'success' => true, 'extension_id' => 42 })

      override = facade.provision_extension(course_url, student_email, assignment_url, new_due_date)

      expect(override).to be_a(Lmss::Pensieve::Override)
      expect(override.id).to eq(42)
      expect(override.student_id).to eq(student_email)
      expect(override.override_due_date).to eq(new_due_date)
    end

    it 'returns nil without calling the API when no synced assignment matches' do
      expect(mock_client).not_to receive(:grant_extension)
      expect(Rails.logger).to receive(:error).with(/no synced assignment with a due date/)

      result = facade.provision_extension(course_url, student_email, 'https://www.pensieve.co/assignments/unknown', new_due_date)
      expect(result).to be_nil
    end

    it 'returns nil without calling the API when the requested date grants no additional days' do
      expect(mock_client).not_to receive(:grant_extension)
      expect(Rails.logger).to receive(:error).with(/grants no additional days/)

      result = facade.provision_extension(course_url, student_email, assignment_url, '2026-08-30T20:00:00Z')
      expect(result).to be_nil
    end

    it 'logs and re-raises API errors' do
      allow(mock_client).to receive(:grant_extension).and_raise(Lmss::Pensieve::RequestError, 'HTTP 500')
      expect(Rails.logger).to receive(:error).with(/Failed to provision Pensieve extension: HTTP 500/)

      expect do
        facade.provision_extension(course_url, student_email, assignment_url, new_due_date)
      end.to raise_error(Lmss::Pensieve::RequestError)
    end
  end

  describe '#ensure_authenticated!' do
    it 'raises PensieveAPIError when PENSIEVE_API_TOKEN is not set' do
      allow(ENV).to receive(:fetch).with('PENSIEVE_API_TOKEN').and_raise(KeyError)
      expect do
        facade.send(:ensure_authenticated!)
      end.to raise_error(PensieveFacade::PensieveAPIError, /PENSIEVE_API_TOKEN must be set/)
    end

    it 'does not create a new client when already authenticated' do
      facade.instance_variable_set(:@pensieve_conn, mock_client)
      expect(Lmss::Pensieve::Client).not_to receive(:new)
      facade.send(:ensure_authenticated!)
    end
  end
end
