require 'rails_helper'

RSpec.describe RequestCsvPresenter do
  let(:course) { create(:course, course_name: 'Test Course', course_code: 'TST101') }
  let(:assignment) do
    Assignment.create!(
      name: 'A1',
      course_to_lms_id: course.course_to_lms(1).id,
      external_assignment_id: 'x1',
      due_date: 2.days.from_now,
      enabled: true
    )
  end

  def csv_for(*requests)
    described_class.new(Request.where(id: requests.map(&:id))).to_csv
  end

  it 'renders a header row and the request data' do
    student = User.create!(email: 's@example.com', canvas_uid: '1', name: 'Student One', student_id: '99')
    request = Request.create!(user: student, course: course, assignment: assignment,
                              reason: 'x', requested_due_date: 4.days.from_now, status: 'pending')

    rows = CSV.parse(csv_for(request))

    expect(rows.first).to eq(described_class::HEADERS)
    expect(rows.second).to include('Student One', '99', 'pending')
  end

  it 'neutralizes formula-injection payloads in user-controlled fields' do
    attacker = User.create!(email: 'evil@example.com', canvas_uid: '2',
                            name: '=HYPERLINK("http://evil","click")', student_id: '+1')
    request = Request.create!(user: attacker, course: course, assignment: assignment,
                              reason: 'x', requested_due_date: 4.days.from_now, status: 'pending')

    parsed = CSV.parse(csv_for(request))
    name_cell = parsed.second[1]
    student_id_cell = parsed.second[2]

    # The leading '=' / '+' is neutralized with a single-quote prefix so a
    # spreadsheet reads the cell as text instead of a formula.
    expect(name_cell).to eq("'#{attacker.name}")
    expect(name_cell).to start_with("'=")
    expect(student_id_cell).to eq("'+1")
  end

  it 'leaves ordinary values untouched' do
    student = User.create!(email: 'ok@example.com', canvas_uid: '3', name: 'Ada Lovelace', student_id: '12345')
    request = Request.create!(user: student, course: course, assignment: assignment,
                              reason: 'x', requested_due_date: 4.days.from_now, status: 'pending')

    parsed = CSV.parse(csv_for(request))

    expect(parsed.second[1]).to eq('Ada Lovelace')
    expect(parsed.second[2]).to eq('12345')
  end
end
