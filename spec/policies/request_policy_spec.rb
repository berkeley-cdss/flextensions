require 'rails_helper'

RSpec.describe RequestPolicy do
  let(:course) { create(:course) }
  let(:assignment) { course.assignments.first }

  let(:teacher_enrollment) { create(:user_to_course, :as_teacher, course: course) }
  let(:leadta_enrollment) { create(:user_to_course, :as_leadta, course: course) }
  let(:ta_enrollment) { create(:user_to_course, :as_ta, course: course) }
  let(:student_enrollment) { create(:user_to_course, :as_student, course: course) }

  let(:student_user) { student_enrollment.user }
  let(:request_record) { create(:request, course: course, user: student_user, assignment: assignment) }

  context 'when user is a site admin' do
    subject { described_class.new(create(:admin), request_record) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:edit) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:cancel) }
    it { is_expected.to permit_action(:approve) }
    it { is_expected.to permit_action(:reject) }
    it { is_expected.to permit_action(:mass_approve) }
    it { is_expected.to permit_action(:mass_reject) }
    it { is_expected.to permit_action(:create_for_student) }
    it { is_expected.to permit_action(:new_for_student) }
  end

  context 'when user is a teacher' do
    subject { described_class.new(teacher_enrollment.user, request_record) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.not_to permit_action(:edit) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.to permit_action(:cancel) }
    it { is_expected.to permit_action(:approve) }
    it { is_expected.to permit_action(:reject) }
    it { is_expected.to permit_action(:mass_approve) }
    it { is_expected.to permit_action(:mass_reject) }
    it { is_expected.to permit_action(:create_for_student) }
    it { is_expected.to permit_action(:new_for_student) }
  end

  context 'when user is a lead TA' do
    subject { described_class.new(leadta_enrollment.user, request_record) }

    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:approve) }
    it { is_expected.to permit_action(:reject) }
    it { is_expected.to permit_action(:create_for_student) }
    it { is_expected.to permit_action(:new_for_student) }
  end

  context 'when user is a regular TA' do
    subject { described_class.new(ta_enrollment.user, request_record) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.not_to permit_action(:edit) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.to permit_action(:cancel) }
    it { is_expected.to permit_action(:approve) }
    it { is_expected.to permit_action(:reject) }
    it { is_expected.to permit_action(:mass_approve) }
    it { is_expected.to permit_action(:mass_reject) }
    it { is_expected.to permit_action(:create_for_student) }
    it { is_expected.to permit_action(:new_for_student) }
  end

  context 'when user is the request owner (student)' do
    subject { described_class.new(student_user, request_record) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:edit) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:cancel) }
    it { is_expected.not_to permit_action(:approve) }
    it { is_expected.not_to permit_action(:reject) }
    it { is_expected.not_to permit_action(:mass_approve) }
    it { is_expected.not_to permit_action(:mass_reject) }
    it { is_expected.not_to permit_action(:create_for_student) }
    it { is_expected.not_to permit_action(:new_for_student) }
  end

  context 'when user is a different student (not owner)' do
    let(:other_student) { create(:user_to_course, :as_student, course: course).user }

    subject { described_class.new(other_student, request_record) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.not_to permit_action(:show) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.not_to permit_action(:edit) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:cancel) }
    it { is_expected.not_to permit_action(:approve) }
    it { is_expected.not_to permit_action(:reject) }
  end
end
