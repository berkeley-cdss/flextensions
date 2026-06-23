require 'date'
require 'json'
require 'ostruct'
require 'rails_helper'
require 'timecop'

describe CanvasFacade do
  let(:mock_auth_token) { 'testAuthToken' }
  let(:course_id) { 16 }
  let(:student_id) { 22 }
  let(:assignment_id) { 18 }
  let(:title) { 'mock_overrideTitle' }
  let(:mock_date) { '2002-03-16:16:00:00Z' }
  let(:override_id) { 8 }
  let(:mock_override) do
    {
      id: override_id,
      assignment_id: assignment_id,
      title: 'mock_override_title',
      due_at: mock_date,
      unlock_at: mock_date,
      lock_at: mock_date,
      student_ids: [ student_id ]
    }
  end

  let(:facade) { described_class.new(mock_auth_token, conn) }
  let(:conn) { Faraday.new { |builder| builder.adapter(:test, stubs) } }
  # Used https://danielabaron.me/blog/testing-faraday-with-rspec/ as reference.
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }

  # Allows each  test to have its own set of stubs.
  after do
    Faraday.default_connection = nil
  end

  describe '#get_assignments' do
    let(:external_course_id) { '123' }
    let(:assignments_response) do
      [
        {
          'id' => '456',
          'name' => 'Assignment 1',
          'due_at' => '2025-01-15T23:59:00Z',
          'all_dates' => [
            { 'base' => true, 'due_at' => '2025-01-15T23:59:00Z' },
            { 'base' => false, 'due_at' => '2025-01-20T23:59:00Z' }
          ]
        }
      ].to_json
    end

    before do
      stubs.get("courses/#{external_course_id}/assignments") do |env|
        [ 200, {}, assignments_response ]
      end
    end

    it 'makes a request with correct parameters' do
      result = facade.get_assignments(external_course_id)
      params = Rack::Utils.parse_query(URI(result.env.url).query)
      expect(params['include[]']).to include('all_dates')
      # override_assignment_dates=false makes the top-level dates the base dates.
      expect(params['override_assignment_dates']).to eq('false')
      expect(params['per_page']).to eq('100')
      expect(result.status).to eq(200)
      expect(result.body).to eq(assignments_response)
    end
  end

  describe '#get_all_assignments' do
    let(:external_course_id) { '123' }
    let(:assignments_data) do
      [
        {
          'id' => '456',
          'name' => 'Assignment 1',
          'due_at' => '2025-01-15T23:59:00Z',
          'all_dates' => [
            { 'base' => true, 'due_at' => '2025-01-15T23:59:00Z', 'lock_at' => '2025-01-20T23:59:00Z' },
            { 'base' => false, 'due_at' => '2025-01-20T23:59:00Z', 'lock_at' => '2025-01-25T23:59:00Z' }
          ]
        },
        {
          'id' => '789',
          'name' => 'Assignment 2',
          'due_at' => '2025-02-15T23:59:00Z',
          'all_dates' => []
        }
      ]
    end

    before do
      allow(facade).to receive_messages(
        get_assignments: instance_double(Faraday::Response),
        depaginate_response: assignments_data
      )
    end

    it 'calls get_assignments and depaginate_response' do
      facade.get_all_assignments(external_course_id)

      expect(facade).to have_received(:get_assignments).with(external_course_id)
      expect(facade).to have_received(:depaginate_response)
    end

    it 'processes assignments to extract base dates' do
      result = facade.get_all_assignments(external_course_id)

      expect(result.first.due_date).to eq(DateTime.parse('2025-01-15T23:59:00Z'))
      expect(result.first.late_due_date).to eq(DateTime.parse('2025-01-20T23:59:00Z'))
      expect(result.second.due_date).to eq(DateTime.parse('2025-02-15T23:59:00Z'))
      expect(result.second.late_due_date).to be_nil
    end

    it 'returns all assignments as Lmss objects' do
      result = facade.get_all_assignments(external_course_id)

      expect(result).to all(be_a(Lmss::Canvas::Assignment))
      expect(result.map(&:id)).to contain_exactly('456', '789')
    end

    context 'when assignment has no all_dates' do
      let(:assignments_data) do
        [
          {
            'id' => '999',
            'name' => 'Assignment without all_dates',
            'due_at' => '2025-03-15T23:59:00Z'
          }
        ]
      end

      it 'falls back to top-level due_at when base dates missing' do
        result = facade.get_all_assignments(external_course_id)

        expect(result.first.due_date).to eq(DateTime.parse('2025-03-15T23:59:00Z'))
        expect(result.first.late_due_date).to be_nil
      end
    end

    context 'when all_dates is truncated for an assignment with >= 25 overrides' do
      # Canvas returns all_dates as an empty array once an assignment has 25 or
      # more dates (ALL_DATES_LIMIT). Because we request
      # override_assignment_dates=false, the top-level due_at/lock_at are still
      # the base dates, so the PORO falls back to them. See docs/Canvas_Dates_API.md.
      let(:assignments_data) do
        [
          {
            'id' => '999',
            'name' => 'Assignment with 25+ overrides',
            'due_at' => '2025-03-20T23:59:00Z',
            'lock_at' => '2025-03-25T23:59:00Z',
            'all_dates' => [],
            'all_dates_count' => 30
          }
        ]
      end

      it 'uses the top-level base dates and does not make an extra API call' do
        expect(facade).not_to receive(:get_base_dates)

        result = facade.get_all_assignments(external_course_id)

        expect(result.first.due_date).to eq(DateTime.parse('2025-03-20T23:59:00Z'))
        expect(result.first.late_due_date).to eq(DateTime.parse('2025-03-25T23:59:00Z'))
      end

      context 'when all_dates_count is set but all_dates is non-empty' do
        # Defensive: all_dates_count is the definitive truncation signal, so we
        # must not trust the (partial) all_dates list even if it has entries.
        let(:assignments_data) do
          [
            {
              'id' => '999',
              'name' => 'Assignment with 25+ overrides',
              'due_at' => '2025-03-20T23:59:00Z',
              'all_dates' => [ { 'base' => true, 'due_at' => '2099-01-01T00:00:00Z' } ],
              'all_dates_count' => 30
            }
          ]
        end

        it 'ignores the truncated all_dates and uses the top-level base date' do
          result = facade.get_all_assignments(external_course_id)

          expect(result.first.due_date).to eq(DateTime.parse('2025-03-20T23:59:00Z'))
        end
      end
    end
  end

  describe '#get_base_dates' do
    let(:assignment_url) { "courses/#{course_id}/assignments/#{assignment_id}" }

    it 'returns the base dates from the assignment endpoint (override_assignment_dates=false)' do
      stubs.get(assignment_url) do |env|
        params = Rack::Utils.parse_query(URI(env.url).query)
        expect(params['override_assignment_dates']).to eq('false')
        [ 200, {}, {
          id: assignment_id,
          due_at: '2025-01-15T23:59:00Z',
          unlock_at: nil,
          lock_at: '2025-01-20T23:59:00Z'
        }.to_json ]
      end

      expect(facade.get_base_dates(course_id, assignment_id)).to eq(
        'due_at' => '2025-01-15T23:59:00Z',
        'unlock_at' => nil,
        'lock_at' => '2025-01-20T23:59:00Z'
      )
      stubs.verify_stubbed_calls
    end

    it 'returns nil when the request fails' do
      stubs.get(assignment_url) { [ 401, {}, '{}' ] }
      expect(facade.get_base_dates(course_id, assignment_id)).to be_nil
    end

    it 'returns nil when the response cannot be parsed' do
      stubs.get(assignment_url) { [ 200, {}, '{invalid json}' ] }
      expect(facade.get_base_dates(course_id, assignment_id)).to be_nil
    end
  end

  describe('initialization') do
    it 'sets the proper URL' do
      expect(Faraday).to receive(:new).with(hash_including(
                                              url: "#{ENV.fetch('CANVAS_URL', nil)}/api/v1"
                                            ))
      described_class.new(mock_auth_token)
    end

    it 'sets the proper token' do
      expect(Faraday).to receive(:new).with(hash_including(
                                              headers: {
                                                Authorization: "Bearer #{mock_auth_token}"
                                              }
                                            ))
      described_class.new(mock_auth_token)
    end
  end

  # NOTE: 2025-08: This method does not return a faraday class.
  # other methods need to be refactors too.
  describe 'get_all_courses' do
    before do
      stubs.get('courses') { [ 200, {}, '[]' ] }
    end

    it 'has correct response body on successful call' do
      expect(facade.get_all_courses).to eq([])
      stubs.verify_stubbed_calls
    end
  end

  describe '#get_all_course_users' do
    let(:course) { instance_double(Course, canvas_id: course_id) }

    it 'uses enrollment_type for built-in Canvas roles' do
      stubs.get("courses/#{course_id}/users?per_page=100&enrollment_type[]=ta") { [ 200, {}, '[]' ] }

      expect(facade.get_all_course_users(course, 'ta')).to eq([])
      stubs.verify_stubbed_calls
    end

    it 'uses enrollment_role for the custom Lead TA Canvas role' do
      stubs.get("courses/#{course_id}/users?per_page=100&enrollment_role=Lead+TA") { [ 200, {}, '[]' ] }

      expect(facade.get_all_course_users(course, 'leadta')).to eq([])
      stubs.verify_stubbed_calls
    end
  end

  describe 'get_course' do
    before do
      stubs.get("courses/#{course_id}") { [ 200, {}, '{}' ] }
    end

    it 'has correct response body on successful call' do
      expect(facade.get_course(course_id).body).to eq('{}')
      stubs.verify_stubbed_calls
    end
  end

  describe('get_assignments') do
    before do
      stubs.get("courses/#{course_id}/assignments") { [ 200, {}, '{}' ] }
    end

    it 'has correct response body on successful call' do
      expect(facade.get_assignments(course_id).body).to eq('{}')
      stubs.verify_stubbed_calls
    end
  end

  describe('get_assignment') do
    before do
      stubs.get("courses/#{course_id}/assignments/#{assignment_id}") { [ 200, {}, '{}' ] }
    end

    it 'has correct response body on successful call' do
      expect(facade.get_assignment(course_id, assignment_id).body).to eq('{}')
      stubs.verify_stubbed_calls
    end

    it 'requests base dates with override_assignment_dates=false' do
      result = facade.get_assignment(course_id, assignment_id)
      params = Rack::Utils.parse_query(URI(result.env.url).query)
      expect(params['override_assignment_dates']).to eq('false')
    end
  end

  describe('get_assignment_overrides') do
    before do
      stubs.get(
        "courses/#{course_id}/assignments/#{assignment_id}/overrides"
      ) { [ 200, {}, '{}' ] }
    end

    it 'has correct response body on successful call' do
      result = facade.get_assignment_overrides(course_id, assignment_id)
      expect(result.body).to eq('{}')
      expect(Rack::Utils.parse_query(URI(result.env.url).query)['per_page']).to eq('100')
      stubs.verify_stubbed_calls
    end
  end

  describe('get_all_assignment_overrides') do
    let(:overrides_url) { "courses/#{course_id}/assignments/#{assignment_id}/overrides" }

    it 'follows pagination links to fetch every override' do
      stubs.get(overrides_url) do
        [
          200,
          { 'Link' => "<#{overrides_url}?page=2&per_page=100>; rel=\"next\"" },
          [ { 'id' => 1 } ].to_json
        ]
      end
      stubs.get("#{overrides_url}?page=2&per_page=100") do
        [ 200, {}, [ { 'id' => 2 } ].to_json ]
      end

      result = facade.get_all_assignment_overrides(course_id, assignment_id)
      expect(result.pluck('id')).to eq([ 1, 2 ])
      stubs.verify_stubbed_calls
    end

    it 'returns a single page when there is no next link' do
      stubs.get(overrides_url) { [ 200, {}, [ { 'id' => 1 } ].to_json ] }

      result = facade.get_all_assignment_overrides(course_id, assignment_id)
      expect(result.pluck('id')).to eq([ 1 ])
      stubs.verify_stubbed_calls
    end
  end

  describe('create_assignment_override') do
    let(:create_assignment_override_url) { "courses/#{course_id}/assignments/#{assignment_id}/overrides" }

    before do
      stubs.post(
        create_assignment_override_url
      ) { [ 200, {}, '{}' ] }
    end

    it 'has correct request body' do
      expect(conn).to receive(:post).with(
        create_assignment_override_url,
        { assignment_override: {
          student_ids: [ student_id ],
          title: title,
          due_at: mock_date,
          unlock_at: mock_date,
          lock_at: mock_date
        } }
      )

      facade.create_assignment_override(
        course_id,
        assignment_id,
        [ student_id ],
        title,
        mock_date,
        mock_date,
        mock_date
      )
    end

    it 'has correct response body on successful call' do
      expect(facade.create_assignment_override(
        course_id,
        assignment_id,
        [ student_id ],
        title,
        mock_date,
        mock_date,
        mock_date
      ).body).to eq('{}')
      stubs.verify_stubbed_calls
    end
  end

  describe('update_assignment_override') do
    let(:update_assignment_overrid_url) do
      "courses/#{course_id}/assignments/#{assignment_id}/overrides/#{override_id}"
    end

    before do
      stubs.put(
        update_assignment_overrid_url
      ) { [ 200, {}, '{}' ] }
    end

    it 'has correct request body' do
      expect(conn).to receive(:put).with(
        update_assignment_overrid_url,
        { assignment_override: {
          student_ids: [ student_id ],
          title: title,
          due_at: mock_date,
          unlock_at: mock_date,
          lock_at: mock_date
        } }
      )

      facade.update_assignment_override(
        course_id,
        assignment_id,
        override_id,
        [ student_id ],
        title,
        mock_date,
        mock_date,
        mock_date
      )
    end

    it 'has correct response body on successful call' do
      expect(facade.update_assignment_override(
        course_id,
        assignment_id,
        override_id,
        [ student_id ],
        title,
        mock_date,
        mock_date,
        mock_date
      ).body).to eq('{}')
      stubs.verify_stubbed_calls
    end
  end

  describe('delete_assignment_override') do
    before do
      stubs.delete(
        "courses/#{course_id}/assignments/#{assignment_id}/overrides/#{override_id}"
      ) { [ 200, {}, '{}' ] }
    end

    it 'has correct response body on successful call' do
      expect(facade.delete_assignment_override(
        course_id,
        assignment_id,
        override_id
      ).body).to eq('{}')
      stubs.verify_stubbed_calls
    end
  end

  describe('provision_extension') do
    let(:mock_override_creation_url) { "courses/#{course_id}/assignments/#{assignment_id}/overrides" }
    let(:create_success_response) { instance_double(Faraday::Response, status: 200, body: '{}') }
    let(:create_invalid_json_response) { instance_double(Faraday::Response, status: 400, body: '{invalid json}') }
    let(:create_taken_response) { instance_double(Faraday::Response, status: 400, body: creation_error_response_already_exists[2]) }
    let(:creation_error_response_already_exists) do
      [
        400,
        {},
        { errors: { assignment_override_students: [ {
          attribute: 'assignment_override_students',
          type: 'taken',
          message: 'already belongs to an assignment override'
        } ] } }.to_json
      ]
    end

    before do
      # With no base due date available, the override title falls back to
      # "Extended to <date>". Title computation itself is covered in the
      # extension_override_title specs.
      allow(facade).to receive_messages(
        get_current_formatted_time: mock_date,
        get_base_dates: nil,
        list_override_structs: [],
        create_assignment_override: create_success_response
      )
    end

    it 'returns correct response body on successful creation' do
      result = facade.provision_extension(
        course_id,
        student_id,
        assignment_id,
        mock_date
      )

      expect(result).to be_a(Lmss::Canvas::Override)
    end

    it 'raises a CanvasAPIError when Canvas rejects the extension' do
      failure_response = instance_double(Faraday::Response, status: 401, body: '{"errors":"unauthorized"}')
      allow(facade).to receive(:create_assignment_override).and_return(failure_response)

      expect do
        facade.provision_extension(
          course_id,
          student_id,
          assignment_id,
          mock_date
        )
      end.to raise_error(CanvasFacade::CanvasAPIError)
    end

    it 'passes nil for close_date (lock_at) when late due date is not provided' do
      expect(facade).to receive(:create_assignment_override).with(
        course_id, assignment_id, [ student_id ],
        "Extended to #{mock_date}",
        mock_date, mock_date, nil
      ).and_return(create_success_response)

      facade.provision_extension(
        course_id,
        student_id,
        assignment_id,
        mock_date
      )
    end

    it 'uses the close_date (late due date) for lock_at when provided' do
      close_date = '2002-03-20T16:00:00Z'
      expect(facade).to receive(:create_assignment_override).with(
        course_id, assignment_id, [ student_id ],
        "Extended to #{mock_date}",
        mock_date, mock_date, close_date
      ).and_return(create_success_response)

      facade.provision_extension(
        course_id,
        student_id,
        assignment_id,
        mock_date,
        close_date
      )
    end

    it 'throws a pipeline error if the creation response body is improperly formatted' do
      allow(facade).to receive(:create_assignment_override).and_return(create_invalid_json_response)
      expect do
        facade.provision_extension(
          course_id,
          student_id,
          assignment_id,
          mock_date
        )
      end.to raise_error(FailedPipelineError)
    end

    it 'throws an error if the existing override cannot be found' do
      allow(facade).to receive_messages(create_assignment_override: create_taken_response, list_override_structs: [])
      expect do
        facade.provision_extension(
          course_id,
          student_id,
          assignment_id,
          mock_date
        )
      end.to raise_error(NotFoundError)
    end

    it 'updates the existing assignment override if the student is the only student the override is provisioned to' do
      allow(facade).to receive(:list_override_structs).and_return([ OpenStruct.new(mock_override) ])
      expect(facade).not_to receive(:create_assignment_override)
      expect(facade).not_to receive(:delete_assignment_override)
      expect(facade).to receive(:update_assignment_override).with(
        course_id,
        assignment_id,
        mock_override[:id],
        mock_override[:student_ids],
        "Extended to #{mock_date}",
        mock_date,
        mock_override[:unlock_at],
        nil
      ).and_return(instance_double(Faraday::Response, status: 200, body: '{}'))
      facade.provision_extension(
        course_id,
        student_id,
        assignment_id,
        mock_date
      )
    end

    it 'renames an existing single-student override without issue' do
      # e.g. moving a student from the "1 day extension" group title to a new
      # one; the rename on update must go through as part of the same request.
      mock_override[:title] = '1 day extension'
      allow(facade).to receive(:list_override_structs).and_return([ OpenStruct.new(mock_override) ])
      expect(facade).to receive(:update_assignment_override).with(
        course_id,
        assignment_id,
        mock_override[:id],
        mock_override[:student_ids],
        "Extended to #{mock_date}",
        mock_date,
        mock_override[:unlock_at],
        nil
      ).and_return(instance_double(Faraday::Response, status: 200, body: '{}'))
      facade.provision_extension(
        course_id,
        student_id,
        assignment_id,
        mock_date
      )
    end

    it 'passes close_date to update when updating existing override' do
      close_date = '2002-03-20T16:00:00Z'
      allow(facade).to receive(:list_override_structs).and_return([ OpenStruct.new(mock_override) ])
      expect(facade).to receive(:update_assignment_override).with(
        course_id,
        assignment_id,
        mock_override[:id],
        mock_override[:student_ids],
        "Extended to #{mock_date}",
        mock_date,
        mock_override[:unlock_at],
        close_date
      ).and_return(instance_double(Faraday::Response, status: 200, body: '{}'))
      facade.provision_extension(
        course_id,
        student_id,
        assignment_id,
        mock_date,
        close_date
      )
    end

    it 'removes the student from a shared override and creates an individual one' do
      mock_override[:student_ids].append(student_id + 1)
      mock_override_struct = OpenStruct.new(mock_override)
      allow(facade).to receive(:list_override_structs).and_return([ mock_override_struct ])
      expect(facade).not_to receive(:delete_assignment_override)
      expect(facade).to receive(:remove_student_from_override).with(
        course_id,
        mock_override_struct,
        student_id
      ).and_return(instance_double(Faraday::Response, status: 200, body: '{}'))
      expect(facade).to receive(:create_assignment_override).with(
        course_id, assignment_id, [ student_id ],
        "Extended to #{mock_date}",
        mock_date, mock_date, nil
      ).and_return(create_success_response)
      facade.provision_extension(
        course_id,
        student_id,
        assignment_id,
        mock_date
      )
    end

    it 'recovers when the student gains an override between the lookup and the create call' do
      expect(facade).to receive(:list_override_structs).twice.and_return([], [ OpenStruct.new(mock_override) ])
      expect(facade).to receive(:create_assignment_override).once.and_return(create_taken_response)
      expect(facade).to receive(:update_assignment_override).with(
        course_id,
        assignment_id,
        mock_override[:id],
        mock_override[:student_ids],
        "Extended to #{mock_date}",
        mock_date,
        mock_override[:unlock_at],
        nil
      ).and_return(instance_double(Faraday::Response, status: 200, body: '{}'))
      facade.provision_extension(
        course_id,
        student_id,
        assignment_id,
        mock_date
      )
    end

    context 'when grouping extensions of the same length' do
      let(:base_due) { '2025-01-15T23:59:00Z' }
      let(:new_due) { '2025-01-16T23:59:00Z' }
      let(:group_override) do
        OpenStruct.new(
          id: 99,
          assignment_id: assignment_id,
          title: '1 day extension',
          due_at: '2025-01-16T23:59:00Z',
          unlock_at: base_due,
          lock_at: nil,
          student_ids: [ student_id + 1 ]
        )
      end

      before do
        allow(facade).to receive(:get_base_dates).and_return({ 'due_at' => base_due })
      end

      it 'adds the student to an existing group override with the same extension' do
        allow(facade).to receive(:list_override_structs).and_return([ group_override ])
        expect(facade).not_to receive(:create_assignment_override)
        expect(facade).to receive(:update_assignment_override).with(
          course_id,
          assignment_id,
          group_override.id,
          [ student_id + 1, student_id ],
          '1 day extension',
          group_override.due_at,
          group_override.unlock_at,
          nil
        ).and_return(instance_double(Faraday::Response, status: 200, body: '{}'))
        facade.provision_extension(course_id, student_id, assignment_id, new_due)
      end

      it 'does nothing when the student is already in the matching group override' do
        group_override.student_ids = [ student_id + 1, student_id ]
        allow(facade).to receive(:list_override_structs).and_return([ group_override ])
        expect(facade).not_to receive(:create_assignment_override)
        expect(facade).not_to receive(:update_assignment_override)
        expect(facade).not_to receive(:delete_assignment_override)

        result = facade.provision_extension(course_id, student_id, assignment_id, new_due)
        expect(result.id).to eq(group_override.id)
      end

      it 'moves a lone student into the matching group and deletes their old override' do
        own_override = OpenStruct.new(
          id: 50,
          assignment_id: assignment_id,
          title: 'Extended to 2025-01-20T23:59:00Z',
          due_at: '2025-01-20T23:59:00Z',
          unlock_at: base_due,
          lock_at: nil,
          student_ids: [ student_id ]
        )
        allow(facade).to receive(:list_override_structs).and_return([ own_override, group_override ])
        expect(facade).not_to receive(:create_assignment_override)
        expect(facade).to receive(:delete_assignment_override).with(course_id, assignment_id, own_override.id)
        expect(facade).to receive(:update_assignment_override).with(
          course_id,
          assignment_id,
          group_override.id,
          [ student_id + 1, student_id ],
          '1 day extension',
          group_override.due_at,
          group_override.unlock_at,
          nil
        ).and_return(instance_double(Faraday::Response, status: 200, body: '{}'))
        facade.provision_extension(course_id, student_id, assignment_id, new_due)
      end

      it 'moves a student out of a shared override into the matching group' do
        shared_override = OpenStruct.new(
          id: 50,
          assignment_id: assignment_id,
          title: '3 days extension',
          due_at: '2025-01-18T23:59:00Z',
          unlock_at: base_due,
          lock_at: nil,
          student_ids: [ student_id, student_id + 2 ]
        )
        allow(facade).to receive(:list_override_structs).and_return([ shared_override, group_override ])
        expect(facade).not_to receive(:create_assignment_override)
        expect(facade).not_to receive(:delete_assignment_override)
        expect(facade).to receive(:remove_student_from_override).with(
          course_id,
          shared_override,
          student_id
        ).and_return(instance_double(Faraday::Response, status: 200, body: '{}'))
        expect(facade).to receive(:update_assignment_override).with(
          course_id,
          assignment_id,
          group_override.id,
          [ student_id + 1, student_id ],
          '1 day extension',
          group_override.due_at,
          group_override.unlock_at,
          nil
        ).and_return(instance_double(Faraday::Response, status: 200, body: '{}'))
        facade.provision_extension(course_id, student_id, assignment_id, new_due)
      end

      it 'does not join a group whose close date differs' do
        group_override.lock_at = '2025-01-19T23:59:00Z'
        allow(facade).to receive(:list_override_structs).and_return([ group_override ])
        expect(facade).not_to receive(:update_assignment_override)
        expect(facade).to receive(:create_assignment_override).with(
          course_id, assignment_id, [ student_id ],
          '1 day extension',
          new_due, mock_date, nil
        ).and_return(create_success_response)
        facade.provision_extension(course_id, student_id, assignment_id, new_due)
      end
    end
  end

  describe 'extension_override_title' do
    it 'titles overrides by extension length so similar extensions share a group' do
      allow(facade).to receive(:get_base_dates).and_return({ 'due_at' => '2025-01-15T23:59:00Z' })
      expect(facade.send(:extension_override_title, course_id, assignment_id, '2025-01-16T23:59:00Z'))
        .to eq('1 day extension')
      expect(facade.send(:extension_override_title, course_id, assignment_id, '2025-01-18T23:59:00Z'))
        .to eq('3 days extension')
    end

    it 'computes the number of days across timezones' do
      allow(facade).to receive(:get_base_dates).and_return({ 'due_at' => '2025-01-16T07:59:00Z' })
      # Base is Jan 15 11:59pm PT; one day later expressed in PT.
      expect(facade.send(:extension_override_title, course_id, assignment_id, '2025-01-16T23:59:00-08:00'))
        .to eq('1 day extension')
    end

    it 'falls back to an absolute title when the base due date is unavailable' do
      allow(facade).to receive(:get_base_dates).and_return(nil)
      expect(facade.send(:extension_override_title, course_id, assignment_id, '2025-01-16T23:59:00Z'))
        .to eq('Extended to 2025-01-16T23:59:00Z')
    end

    it 'falls back to an absolute title when the new date is not at least a day later' do
      allow(facade).to receive(:get_base_dates).and_return({ 'due_at' => '2025-01-15T23:59:00Z' })
      expect(facade.send(:extension_override_title, course_id, assignment_id, '2025-01-15T20:00:00Z'))
        .to eq('Extended to 2025-01-15T20:00:00Z')
    end
  end

  describe 'get_existing_student_override' do
    let(:get_assignment_overrides_url) { "courses/#{course_id}/assignments/#{assignment_id}/overrides" }

    it 'throws an error if the overrides response body cannot be parsed' do
      stubs.get(get_assignment_overrides_url) { [ 200, {}, '{invalid json}' ] }
      expect do
        facade.send(
          :get_existing_student_override,
          course_id,
          student_id,
          assignment_id
        )
      end.to raise_error(FailedPipelineError)
    end

    it 'returns the override that the student is listed in' do
      mock_overrideWithoutStudent = mock_override.clone
      mock_overrideWithoutStudent[:student_ids] = [ student_id + 1 ]
      stubs.get(get_assignment_overrides_url) do
        [
          200,
          {},
          [ mock_overrideWithoutStudent, mock_override ].to_json
        ]
      end
      expect(facade.send(
        :get_existing_student_override,
        course_id,
        student_id,
        assignment_id
      ).student_ids[0]).to eq(student_id)
    end

    it 'returns nil if no override for that student is found' do
      mock_override[:student_ids] = [ student_id + 1 ]
      stubs.get(get_assignment_overrides_url) do
        [
          200,
          {},
          [ mock_override ].to_json
        ]
      end
      expect(facade.send(
               :get_existing_student_override,
               course_id,
               student_id,
               assignment_id
             )).to be_nil
    end

    it 'throws an error if the overrides request fails' do
      stubs.get(get_assignment_overrides_url) { [ 401, {}, '{"errors":"unauthorized"}' ] }
      expect do
        facade.send(
          :get_existing_student_override,
          course_id,
          student_id,
          assignment_id
        )
      end.to raise_error(FailedPipelineError)
    end

    it 'finds an override beyond the first page of results' do
      mock_override_other_student = mock_override.clone
      mock_override_other_student[:student_ids] = [ student_id + 1 ]
      stubs.get(get_assignment_overrides_url) do
        [
          200,
          { 'Link' => "<#{get_assignment_overrides_url}?page=2&per_page=100>; rel=\"next\"" },
          [ mock_override_other_student ].to_json
        ]
      end
      stubs.get("#{get_assignment_overrides_url}?page=2&per_page=100") do
        [ 200, {}, [ mock_override ].to_json ]
      end
      expect(facade.send(
        :get_existing_student_override,
        course_id,
        student_id,
        assignment_id
      ).id).to eq(override_id)
    end

    it 'skips overrides with nil student_ids' do
      mock_override_nil_students = mock_override.clone
      mock_override_nil_students[:student_ids] = nil
      stubs.get(get_assignment_overrides_url) do
        [
          200,
          {},
          [ mock_override_nil_students, mock_override ].to_json
        ]
      end
      expect(facade.send(
               :get_existing_student_override,
               course_id,
               student_id,
               assignment_id
             ).student_ids[0]).to eq(student_id)
    end
  end

  describe 'get_current_formatted_time' do
    before do
      Timecop.freeze(DateTime.new(2002, 0o3, 16, 16))
    end

    it 'outputs the current time in Canvas iso8601 formatting' do
      expect(facade.send(:get_current_formatted_time)).to eq('2002-03-16T16:00:00Z')
    end
  end

  describe 'remove_student_from_override' do
    let(:mock_override_struct) { OpenStruct.new(mock_override) }

    before do
      mock_override_struct.student_ids.append(student_id + 1)
    end

    it 'removes the student and keeps the title and dates the same' do
      mock_overrideWithoutStudent = OpenStruct.new(mock_override)
      mock_overrideWithoutStudent.student_ids = [ student_id + 1 ]
      expect(facade).to receive(:update_assignment_override).with(
        course_id,
        mock_override_struct.assignment_id,
        mock_override_struct.id,
        [ student_id + 1 ],
        mock_override_struct.title,
        mock_override_struct.due_at,
        mock_override_struct.unlock_at,
        mock_override_struct.lock_at
      ).and_return(OpenStruct.new({ status: 200, body: mock_overrideWithoutStudent.to_h.to_json }))
      expect(facade.send(
               :remove_student_from_override,
               course_id,
               mock_override_struct,
               student_id
             ))
    end

    it 'does not mutate the student_ids on the override being updated' do
      allow(facade).to receive(:update_assignment_override).and_return(
        OpenStruct.new({ status: 200, body: { student_ids: [ student_id + 1 ] }.to_json })
      )
      facade.send(:remove_student_from_override, course_id, mock_override_struct, student_id)
      expect(mock_override_struct.student_ids).to include(student_id)
    end

    it 'throws a pipeline error if the student cannot be removed from the override' do
      expect(facade).to receive(:update_assignment_override).with(
        course_id,
        mock_override_struct.assignment_id,
        mock_override_struct.id,
        [ student_id + 1 ],
        mock_override_struct.title,
        mock_override_struct.due_at,
        mock_override_struct.unlock_at,
        mock_override_struct.lock_at
      ).and_return(OpenStruct.new({ status: 200, body: mock_override_struct.to_h.to_json }))
      expect do
        facade.send(
          :remove_student_from_override,
          course_id,
          mock_override_struct,
          student_id
        )
      end.to raise_error(FailedPipelineError)
    end

    it 'throws a pipeline error if the update request fails' do
      allow(facade).to receive(:update_assignment_override).and_return(
        OpenStruct.new({ status: 400, body: '{"errors":"bad request"}' })
      )
      expect do
        facade.send(
          :remove_student_from_override,
          course_id,
          mock_override_struct,
          student_id
        )
      end.to raise_error(FailedPipelineError)
    end
  end
end
