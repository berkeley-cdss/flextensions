require 'rails_helper'

RSpec.describe CoursePolicy do
  subject { described_class.new(user, course) }

  let(:course) { create(:course) }

  let(:teacher_enrollment) { create(:user_to_course, :as_teacher, course: course) }
  let(:leadta_enrollment) { create(:user_to_course, :as_leadta, course: course) }
  let(:ta_enrollment) { create(:user_to_course, :as_ta, course: course) }
  let(:student_enrollment) { create(:user_to_course, :as_student, course: course) }

  context 'when user is a site admin' do
    let(:user) { create(:admin) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:edit) }
    it { is_expected.to permit_action(:enrollments) }
    it { is_expected.to permit_action(:delete) }
    it { is_expected.to permit_action(:sync_assignments) }
    it { is_expected.to permit_action(:sync_enrollments) }
  end

  context 'when user is a teacher (course admin)' do
    let(:user) { teacher_enrollment.user }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:edit) }
    it { is_expected.to permit_action(:enrollments) }
    it { is_expected.to permit_action(:delete) }
    it { is_expected.to permit_action(:sync_assignments) }
    it { is_expected.to permit_action(:sync_enrollments) }
  end

  context 'when user is a lead TA (course admin)' do
    let(:user) { leadta_enrollment.user }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:edit) }
    it { is_expected.to permit_action(:enrollments) }
    it { is_expected.to permit_action(:delete) }
    it { is_expected.to permit_action(:sync_assignments) }
    it { is_expected.to permit_action(:sync_enrollments) }
  end

  context 'when user is a regular TA' do
    let(:user) { ta_enrollment.user }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.not_to permit_action(:edit) }
    it { is_expected.to permit_action(:enrollments) }
    it { is_expected.not_to permit_action(:delete) }
    it { is_expected.to permit_action(:sync_assignments) }
    it { is_expected.to permit_action(:sync_enrollments) }
  end

  context 'when user is a student' do
    let(:user) { student_enrollment.user }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.not_to permit_action(:edit) }
    it { is_expected.not_to permit_action(:enrollments) }
    it { is_expected.not_to permit_action(:delete) }
    it { is_expected.not_to permit_action(:sync_assignments) }
    it { is_expected.not_to permit_action(:sync_enrollments) }
  end

  context 'when user is not enrolled' do
    let(:user) { create(:user) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.not_to permit_action(:show) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.not_to permit_action(:edit) }
    it { is_expected.not_to permit_action(:enrollments) }
    it { is_expected.not_to permit_action(:delete) }
    it { is_expected.not_to permit_action(:sync_assignments) }
    it { is_expected.not_to permit_action(:sync_enrollments) }
  end
end
