require 'rails_helper'

RSpec.describe StaleExtensionRemover do
  subject(:remover) { described_class.new(course_to_lms, facade) }

  let(:course) { create(:course) }
  let(:course_to_lms) { course.course_to_lms(1) }
  let(:facade) { instance_double(CanvasFacade) }
  let(:original_due_date) { Time.zone.parse('2026-11-05 23:59:00') }
  let(:extended_due_date) { Time.zone.parse('2026-11-06 23:59:00') }
  let(:class_due_date) { Time.zone.parse('2026-11-20 23:59:00') }
  let(:assignment) do
    create(:assignment, course_to_lms: course_to_lms, external_assignment_id: 'hw1', due_date: original_due_date)
  end
  let(:student) { create(:user, canvas_uid: '101') }
  let(:lms_due_dates) { { 101 => extended_due_date } }

  def approve_extension(user, due_date, target: assignment)
    create(:request, :approved, course: course, assignment: target, user: user, requested_due_date: due_date)
  end

  # Moves the class deadline after the extensions in the test were approved.
  def move_deadline(to: class_due_date, target: assignment)
    target.update!(due_date: to)
  end

  before do
    allow(facade).to receive(:student_identifier) { |user| user.canvas_uid.to_i }
    allow(facade).to receive_messages(extension_due_dates: lms_due_dates, remove_extension: true)
  end

  context 'when the class deadline moved past an approved extension' do
    before do
      approve_extension(student, extended_due_date)
      move_deadline
    end

    it 'removes the extension from the LMS' do
      expect(remover.call([ 'hw1' ])).to eq(removed: 1, skipped: 0, failed: 0)
      expect(facade).to have_received(:remove_extension).with(course_to_lms.external_course_id, 101, 'hw1')
    end

    it 'keeps the request as a record of what was approved' do
      request = Request.find_by!(user: student)

      expect { remover.call([ 'hw1' ]) }.not_to(change { request.reload.attributes })
    end

    it 'ignores a difference in seconds added by the LMS' do
      allow(facade).to receive(:extension_due_dates).and_return(101 => extended_due_date + 59.seconds)

      expect(remover.call([ 'hw1' ])).to include(removed: 1)
    end

    context 'when the extension was already removed' do
      let(:lms_due_dates) { {} }

      it 'changes nothing, so syncing again is safe' do
        expect(remover.call([ 'hw1' ])).to eq(removed: 0, skipped: 0, failed: 0)
        expect(facade).not_to have_received(:remove_extension)
      end
    end

    context 'when the LMS has a date Flextensions did not approve' do
      let(:lms_due_dates) { { 101 => extended_due_date + 2.days } }

      it 'leaves it alone and reports it' do
        expect(remover.call([ 'hw1' ])).to eq(removed: 0, skipped: 1, failed: 0)
        expect(facade).not_to have_received(:remove_extension)
      end
    end

    context 'when the student also has a later extension in the LMS' do
      let(:lms_due_dates) { { 101 => class_due_date + 5.days } }

      it 'leaves the later extension in place' do
        approve_extension(student, class_due_date + 5.days)

        expect(remover.call([ 'hw1' ])).to eq(removed: 0, skipped: 0, failed: 0)
        expect(facade).not_to have_received(:remove_extension)
      end
    end

    context 'when the student has more than one outdated extension' do
      let(:lms_due_dates) { { 101 => extended_due_date + 3.days } }

      it 'removes the one in the LMS once' do
        move_deadline(to: original_due_date)
        approve_extension(student, extended_due_date + 3.days)
        move_deadline

        expect(remover.call([ 'hw1' ])).to include(removed: 1)
        expect(facade).to have_received(:remove_extension).once
      end
    end

    it 'skips assignments that no longer exist in the LMS' do
      expect(remover.call([ 'other' ])).to eq(removed: 0, skipped: 0, failed: 0)
      expect(facade).not_to have_received(:extension_due_dates)
    end
  end

  context 'with extensions that are still later than the class deadline' do
    before do
      approve_extension(student, extended_due_date)
      move_deadline(to: extended_due_date - 12.hours)
    end

    it 'does not contact the LMS' do
      expect(remover.call([ 'hw1' ])).to eq(removed: 0, skipped: 0, failed: 0)
      expect(facade).not_to have_received(:extension_due_dates)
    end
  end

  it 'does not touch pending or denied requests' do
    create(:request, course: course, assignment: assignment, user: student, requested_due_date: extended_due_date)
    create(:request, :denied, course: course, assignment: assignment, user: student, requested_due_date: extended_due_date)
    move_deadline

    expect(remover.call([ 'hw1' ])).to eq(removed: 0, skipped: 0, failed: 0)
  end

  it 'does not touch another LMS link in the same course' do
    gradescope_link = create(:course_to_lms, course: course, lms: Lms.find_by(id: 2) || create(:lms, :gradescope))
    other = create(:assignment, course_to_lms: gradescope_link, external_assignment_id: 'hw1', due_date: original_due_date)
    approve_extension(student, extended_due_date, target: other)
    move_deadline(target: other)

    expect(remover.call([ 'hw1' ])).to eq(removed: 0, skipped: 0, failed: 0)
  end

  context 'with the real Canvas facade' do
    let(:facade) { CanvasFacade.new('token') }
    let(:other_student) { create(:user, canvas_uid: '102') }
    let(:overrides_url) { "#{CanvasFacade::CANVAS_URL}/api/v1/courses/#{course_to_lms.external_course_id}/assignments/hw1/overrides" }
    let(:shared_override) do
      { id: 7, assignment_id: 'hw1', title: '1 day extension', due_at: '2026-11-06T23:59:59-08:00',
        unlock_at: nil, lock_at: nil, student_ids: [ 101, 102, 103 ] }
    end

    def overrides_response(override)
      { status: 200, body: [ override ].to_json, headers: { 'Content-Type' => 'application/json' } }
    end

    before do
      allow(facade).to receive(:student_identifier).and_call_original
      allow(facade).to receive(:extension_due_dates).and_call_original
      allow(facade).to receive(:remove_extension).and_call_original
      approve_extension(student, extended_due_date)
      approve_extension(other_student, extended_due_date)
      move_deadline
    end

    it 'takes both students off a shared override without restoring either or affecting anyone else' do
      stub_request(:get, overrides_url).with(query: hash_including({})).to_return(
        overrides_response(shared_override),
        overrides_response(shared_override),
        overrides_response(shared_override.merge(student_ids: [ 102, 103 ]))
      )
      update = stub_request(:put, "#{overrides_url}/7").to_return do |request|
        { status: 200, body: { student_ids: Rack::Utils.parse_nested_query(request.body)['assignment_override']['student_ids'] }.to_json }
      end

      expect(remover.call([ 'hw1' ])).to eq(removed: 2, skipped: 0, failed: 0)

      student_ids_sent = []
      expect(update.with { |request| student_ids_sent << Rack::Utils.parse_nested_query(request.body)['assignment_override']['student_ids'] })
        .to have_been_requested.twice
      expect(student_ids_sent.uniq).to eq([ %w[102 103], [ '103' ] ])
    end

    it 'deletes an override once its only student is removed' do
      solo_override = shared_override.merge(student_ids: [ 101 ])
      stub_request(:get, overrides_url).with(query: hash_including({})).to_return(overrides_response(solo_override))
      delete = stub_request(:delete, "#{overrides_url}/7").to_return(status: 200, body: '{}')

      expect(remover.call([ 'hw1' ])).to eq(removed: 1, skipped: 0, failed: 0)
      expect(delete).to have_been_requested.once
    end
  end

  context 'with the real Gradescope facade' do
    let(:course_id) { '555' }
    let(:gradescope_link) do
      create(:course_to_lms, course: course, lms: Lms.find_by(id: 2) || create(:lms, :gradescope), external_course_id: course_id)
    end
    let(:gradescope_assignment) do
      create(:assignment, course_to_lms: gradescope_link, external_assignment_id: '42', due_date: original_due_date)
    end
    let(:student) { create(:user, email: 'student@example.com') }
    let(:base_url) { "#{Lmss::Gradescope::Client::BASE_URL}/courses/#{course_id}/assignments/42/extensions" }

    def extensions_html(with_extension:)
      add_props = { students: [ { id: 111, email: 'student@example.com' } ] }.to_json
      edit_props = { deletePath: '/courses/555/assignments/42/extensions/9',
                     override: { user_id: 111, settings: { due_date: { value: '2026-11-06T23:59:00-08:00' } } } }.to_json
      edit_element = with_extension ? %(<div data-react-class="EditExtension" data-react-props="#{CGI.escapeHTML(edit_props)}"></div>) : ''
      %(<html><body><div data-react-class="AddExtension" data-react-props="#{CGI.escapeHTML(add_props)}"></div>#{edit_element}</body></html>)
    end

    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('GRADESCOPE_EMAIL').and_return('bot@example.com')
      allow(ENV).to receive(:fetch).with('GRADESCOPE_PASSWORD').and_return('test-password')
      login_page = { status: 200, body: '<meta name="csrf-token" content="csrf-token">' }
      stub_request(:get, "#{Lmss::Gradescope::Client::BASE_URL}/login").to_return(login_page)
      stub_request(:post, "#{Lmss::Gradescope::Client::BASE_URL}/login").to_return(status: 302)
      stub_request(:get, "#{Lmss::Gradescope::Client::BASE_URL}/account").to_return(login_page)
    end

    it 'finds the extension by email, deletes it, and confirms that it is gone' do
      stub_request(:get, base_url).to_return(
        { status: 200, body: extensions_html(with_extension: true) },
        { status: 200, body: extensions_html(with_extension: true) },
        { status: 200, body: extensions_html(with_extension: false) }
      )
      delete = stub_request(:delete, "#{base_url}/9").with(headers: { 'X-CSRF-Token' => 'csrf-token' }).to_return(status: 302)
      approve_extension(student, extended_due_date, target: gradescope_assignment)
      move_deadline(target: gradescope_assignment)

      expect(described_class.new(gradescope_link, GradescopeFacade.new).call([ '42' ])).to eq(removed: 1, skipped: 0, failed: 0)
      expect(delete).to have_been_requested.once
    end

    it 'counts a delete that Gradescope ignored as a failure' do
      stub_request(:get, base_url).to_return(status: 200, body: extensions_html(with_extension: true))
      stub_request(:delete, "#{base_url}/9").to_return(status: 302)
      allow(Rails.error).to receive(:report)
      approve_extension(student, extended_due_date, target: gradescope_assignment)
      move_deadline(target: gradescope_assignment)

      expect(described_class.new(gradescope_link, GradescopeFacade.new).call([ '42' ])).to eq(removed: 0, skipped: 0, failed: 1)
    end
  end

  context 'when the LMS reports failures' do
    let(:other_student) { create(:user, canvas_uid: '102') }
    let(:lms_due_dates) { { 101 => extended_due_date, 102 => extended_due_date } }

    before do
      approve_extension(student, extended_due_date)
      approve_extension(other_student, extended_due_date)
      move_deadline
      allow(Rails.error).to receive(:report)
    end

    it 'keeps going when one student fails and reports the error' do
      error = CanvasFacade::CanvasAPIError.new('nope')
      allow(facade).to receive(:remove_extension).with(anything, 101, anything).and_raise(error)

      expect(remover.call([ 'hw1' ])).to eq(removed: 1, skipped: 0, failed: 1)
      expect(Rails.error).to have_received(:report).with(
        error, hash_including(handled: true, context: hash_including(component: 'stale_extensions', user_id: student.id))
      )
    end

    it 'counts every student as failed when the extensions cannot be read' do
      allow(facade).to receive(:extension_due_dates).and_raise(CanvasFacade::CanvasAPIError, 'nope')

      expect(remover.call([ 'hw1' ])).to eq(removed: 0, skipped: 0, failed: 2)
    end

    it 'still reviews other assignments when one cannot be read' do
      other = create(:assignment, course_to_lms: course_to_lms, external_assignment_id: 'hw2', due_date: original_due_date)
      approve_extension(student, extended_due_date, target: other)
      move_deadline(target: other)
      allow(facade).to receive(:extension_due_dates).with(anything, 'hw1').and_raise(CanvasFacade::CanvasAPIError, 'nope')
      allow(facade).to receive(:extension_due_dates).with(anything, 'hw2').and_return(lms_due_dates)

      expect(remover.call(%w[hw1 hw2])).to eq(removed: 1, skipped: 0, failed: 2)
    end
  end
end
