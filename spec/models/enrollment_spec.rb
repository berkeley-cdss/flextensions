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
end
