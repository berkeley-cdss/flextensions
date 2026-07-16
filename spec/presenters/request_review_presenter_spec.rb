require 'rails_helper'

RSpec.describe RequestReviewPresenter do
  subject(:presenter) { described_class.new(request) }

  let(:course) { create(:course) }
  let(:course_to_lms) { course.course_to_lms(1) }
  let(:student) { create(:user) }
  let(:assignment) do
    Assignment.create!(
      name: 'A1', course_to_lms_id: course_to_lms.id,
      due_date: 2.days.from_now, late_due_date: 4.days.from_now,
      external_assignment_id: 'x1', enabled: true
    )
  end
  let(:request) do
    Request.create!(user: student, course:, assignment:,
                    reason: 'Need time', requested_due_date: 5.days.from_now)
  end

  describe '#student_requests' do
    it "returns the student's other requests in the course, excluding this one" do
      other_assignment = Assignment.create!(
        name: 'A2', course_to_lms_id: course_to_lms.id,
        due_date: 3.days.from_now, external_assignment_id: 'x2', enabled: true
      )
      prior = Request.create!(user: student, course:, assignment: other_assignment,
                              reason: 'Earlier', requested_due_date: 6.days.from_now, status: 'approved')

      expect(presenter.student_requests).to contain_exactly(prior)
    end

    it "excludes other students' requests" do
      other_student = create(:user)
      Request.create!(user: other_student, course:, assignment:,
                      reason: 'Theirs', requested_due_date: 6.days.from_now)

      expect(presenter.student_requests).to be_empty
    end
  end

  describe 'status counts' do
    before do
      %w[approved approved denied pending].each_with_index do |status, i|
        a = Assignment.create!(
          name: "Extra #{i}", course_to_lms_id: course_to_lms.id,
          due_date: 3.days.from_now, external_assignment_id: "extra-#{i}", enabled: true
        )
        Request.create!(user: student, course:, assignment: a,
                        reason: 'r', requested_due_date: 6.days.from_now, status:)
      end
    end

    it 'counts each status, excluding the current request' do
      expect(presenter.approved_count).to eq(2)
      expect(presenter.denied_count).to eq(1)
      expect(presenter.pending_count).to eq(1)
    end
  end

  describe '#allow_extended_requests?' do
    it 'is true when the enrollment allows extended requests' do
      Enrollment.create!(user: student, course:, role: 'student', allow_extended_requests: true)
      expect(presenter.allow_extended_requests?).to be(true)
    end

    it 'is false when there is no enrollment' do
      expect(presenter.allow_extended_requests?).to be(false)
    end
  end

  describe '#new_late_due_date' do
    it 'returns the late due date that would be applied on approval' do
      expect(presenter.new_late_due_date).to eq(request.calculate_new_late_due_date)
    end
  end

  describe '#submitted_after_deadline?' do
    it 'is false when submitted before the original due date' do
      expect(presenter.submitted_after_deadline?).to be(false)
    end

    it 'is true when submitted after the original due date' do
      request.update!(created_at: assignment.due_date + 1.day)
      expect(presenter.submitted_after_deadline?).to be(true)
    end
  end
end
