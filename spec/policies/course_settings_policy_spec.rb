require 'rails_helper'

RSpec.describe CourseSettingsPolicy do
  subject { described_class.new(user, course.course_settings) }

  let(:course) { create(:course) }

  context 'when user is a site admin' do
    let(:user) { create(:admin) }

    it { is_expected.to permit_action(:update) }
  end

  context 'when user is a teacher (course admin)' do
    let(:user) { create(:user_to_course, :as_teacher, course: course).user }

    it { is_expected.to permit_action(:update) }
  end

  context 'when user is a lead TA (course admin)' do
    let(:user) { create(:user_to_course, :as_leadta, course: course).user }

    it { is_expected.to permit_action(:update) }
  end

  context 'when user is a regular TA' do
    let(:user) { create(:user_to_course, :as_ta, course: course).user }

    it { is_expected.not_to permit_action(:update) }
  end

  context 'when user is a student' do
    let(:user) { create(:user_to_course, :as_student, course: course).user }

    it { is_expected.not_to permit_action(:update) }
  end
end
