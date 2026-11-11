# == Schema Information
#
# Table name: assignments
#
#  id                     :bigint           not null, primary key
#  due_date               :datetime
#  enabled                :boolean          default(FALSE)
#  late_due_date          :datetime
#  name                   :string
#  release_date           :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  course_id              :bigint           not null
#  course_to_lms_id       :bigint           not null
#  external_assignment_id :string
#
# Indexes
#
#  index_assignments_on_course_id  (course_id)
#
# Foreign Keys
#
#  fk_rails_...  (course_id => courses.id)
#  fk_rails_...  (course_to_lms_id => course_to_lmss.id)
#
require 'rails_helper'

RSpec.describe Assignment, type: :model do
  it 'has a valid factory' do
    expect(build(:assignment)).to be_valid
  end

  describe 'course denormalization' do
    it 'defaults course to the course_to_lms course on save' do
      course = create(:course)
      assignment = create(:assignment, course_to_lms: course.course_to_lms(1))
      expect(assignment.course).to eq(course)
    end

    it 'is invalid without a course or course_to_lms' do
      assignment = build(:assignment, course_to_lms: nil)
      expect(assignment).not_to be_valid
      expect(assignment.errors[:course]).to include('must exist')
    end
  end

  describe 'custom validations' do
    context 'enabled_requires_date_present' do
      it 'is valid when enabled is false and due_date is blank' do
        assignment = build(:assignment, enabled: false, due_date: nil)
        expect(assignment).to be_valid
      end

      it 'is valid when enabled is true and due_date is present' do
        assignment = build(:assignment, enabled: true, due_date: 2.days.from_now)
        expect(assignment).to be_valid
      end

      it 'is invalid when enabled is true and due_date is blank' do
        assignment = build(:assignment, enabled: true, due_date: nil)
        expect(assignment).not_to be_valid
        expect(assignment.errors[:due_date]).to include('must be present if assignment is enabled')
      end
    end
  end

  describe '#external_url' do
    it 'builds the LMS assignment URL from the linked LMS and course' do
      lms = Lms.find_by(id: CANVAS_LMS_ID) || create(:lms, id: CANVAS_LMS_ID, lms_name: 'Canvas')
      lms.update!(lms_base_url: 'https://canvas.example.edu')
      course_to_lms = create(:course_to_lms, lms: lms, external_course_id: '4567')
      assignment = create(:assignment, course_to_lms: course_to_lms, external_assignment_id: '89')

      expect(assignment.external_url)
        .to eq('https://canvas.example.edu/courses/4567/assignments/89')
    end
  end

  describe '#current_due_date_for' do
    let(:assignment) { create(:assignment, due_date: Time.zone.parse('2026-11-05 23:59')) }
    let(:student) { create(:user) }

    def approve_until(due_date, user: student)
      create(:request, :approved, course: assignment.course, assignment: assignment, user: user, requested_due_date: due_date)
    end

    it 'is the class deadline when the student has no approved extension' do
      create(:request, course: assignment.course, assignment: assignment, user: student,
                       requested_due_date: Time.zone.parse('2026-11-09 23:59'))

      expect(assignment.current_due_date_for(student)).to eq(assignment.due_date)
    end

    it 'is the extension while it is later than the class deadline' do
      approve_until(Time.zone.parse('2026-11-06 23:59'))

      expect(assignment.current_due_date_for(student)).to eq(Time.zone.parse('2026-11-06 23:59'))
    end

    it 'is the class deadline once it moves past the extension' do
      approve_until(Time.zone.parse('2026-11-06 23:59'))
      assignment.update!(due_date: Time.zone.parse('2026-11-20 23:59'))

      expect(assignment.current_due_date_for(student)).to eq(Time.zone.parse('2026-11-20 23:59'))
    end

    it 'uses the most recent approval, which replaces earlier ones in the LMS' do
      approve_until(Time.zone.parse('2026-11-10 23:59'))
      travel(1.minute) { approve_until(Time.zone.parse('2026-11-07 23:59')) }

      expect(assignment.current_due_date_for(student)).to eq(Time.zone.parse('2026-11-07 23:59'))
    end

    it "ignores other students' extensions" do
      approve_until(Time.zone.parse('2026-11-06 23:59'), user: create(:user))

      expect(assignment.current_due_date_for(student)).to eq(assignment.due_date)
    end

    it 'is nil when there is no date at all' do
      assignment.update!(due_date: nil)

      expect(assignment.current_due_date_for(student)).to be_nil
    end
  end
end
