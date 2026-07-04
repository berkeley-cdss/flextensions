# == Schema Information
#
# Table name: enrollments
#
#  id                      :bigint           not null, primary key
#  allow_extended_requests :boolean          default(FALSE), not null
#  removed                 :boolean          default(FALSE), not null
#  role                    :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  course_id               :bigint
#  user_id                 :bigint
#
# Indexes
#
#  index_enrollments_on_course_id  (course_id)
#  index_enrollments_on_user_id    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (course_id => courses.id)
#  fk_rails_...  (user_id => users.id)
#
require 'rails_helper'

RSpec.describe Enrollment, type: :model do
  describe 'Lead TA role support' do
    it 'treats leadta as a supported staff role' do
      enrollment = build(:enrollment, role: 'leadta')

      expect(described_class.staff_roles).to include('leadta')
      expect(described_class.roles).to include('leadta')
      expect(enrollment).to be_staff
    end

    it 'treats leadta as a course admin role' do
      enrollment = build(:enrollment, role: 'leadta')

      expect(enrollment).to be_course_admin
    end
  end

  describe '.role_from_canvas_enrollment' do
    it 'normalizes Canvas Lead TA custom role enrollments' do
      enrollment = { 'type' => 'ta', 'role' => 'Lead TA' }

      expect(described_class.role_from_canvas_enrollment(enrollment)).to eq('leadta')
    end

    it 'falls back to the Canvas enrollment type for built-in roles' do
      enrollment = { 'type' => 'teacher' }

      expect(described_class.role_from_canvas_enrollment(enrollment)).to eq('teacher')
    end
  end

  describe '#display_role' do
    it 'formats leadta as Lead TA' do
      enrollment = build(:enrollment, role: 'leadta')

      expect(enrollment.display_role).to eq('Lead TA')
    end
  end

  describe '.keep_highest_role' do
    let(:user) { create(:user) }
    let(:course) { create(:course) }

    it 'keeps only the highest-ranked role when a user has several in one course' do
      create(:enrollment, user: user, course: course, role: 'ta')
      create(:enrollment, user: user, course: course, role: 'teacher')

      result = described_class.where(user: user, course: course).keep_highest_role

      expect(result.map(&:role)).to eq([ 'teacher' ])
    end

    it 'keeps one enrollment per course' do
      other_course = create(:course)
      create(:enrollment, user: user, course: course, role: 'ta')
      create(:enrollment, user: user, course: course, role: 'leadta')
      create(:enrollment, user: user, course: other_course, role: 'student')

      result = described_class.where(user: user).keep_highest_role

      expect(result.map(&:course_id)).to contain_exactly(course.id, other_course.id)
      expect(result.find { |e| e.course_id == course.id }.role).to eq('leadta')
    end
  end
end
