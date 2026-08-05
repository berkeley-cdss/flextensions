# == Schema Information
#
# Table name: assignments
#
#  id                     :bigint           not null, primary key
#  due_date               :datetime
#  enabled                :boolean          default(FALSE)
#  late_due_date          :datetime
#  name                   :string
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
end
