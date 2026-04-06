require 'rails_helper'

RSpec.describe CoursePolicy do
  let(:course) { create(:course) }
  let(:student_user) { create(:user, :with_canvas_token, courses: [ course ], role: 'student') }
  let(:ta_user) { create(:user, :with_canvas_token, courses: [ course ], role: 'ta') }
  let(:leadta_user) { create(:user, :with_canvas_token, courses: [ course ], role: 'leadta') }
  let(:teacher_user) { create(:user, :with_canvas_token, courses: [ course ], role: 'teacher') }
  let(:admin_user) { create(:admin, :with_canvas_token) }
  let(:unenrolled_user) { create(:user, :with_canvas_token) }

  def policy_for(user)
    CoursePolicy.new(user, course)
  end

  describe 'role checks' do
    describe '#site_admin?' do
      it 'returns true for admin users' do
        expect(policy_for(admin_user).site_admin?).to be true
      end

      it 'returns false for non-admin users' do
        expect(policy_for(student_user).site_admin?).to be false
        expect(policy_for(teacher_user).site_admin?).to be false
      end
    end

    describe '#course_admin?' do
      it 'returns true for teachers' do
        expect(policy_for(teacher_user).course_admin?).to be true
      end

      it 'returns true for lead TAs' do
        expect(policy_for(leadta_user).course_admin?).to be true
      end

      it 'returns true for site admins' do
        expect(policy_for(admin_user).course_admin?).to be true
      end

      it 'returns false for regular TAs' do
        expect(policy_for(ta_user).course_admin?).to be false
      end

      it 'returns false for students' do
        expect(policy_for(student_user).course_admin?).to be false
      end
    end

    describe '#staff?' do
      it 'returns true for teachers' do
        expect(policy_for(teacher_user).staff?).to be true
      end

      it 'returns true for lead TAs' do
        expect(policy_for(leadta_user).staff?).to be true
      end

      it 'returns true for regular TAs' do
        expect(policy_for(ta_user).staff?).to be true
      end

      it 'returns true for site admins' do
        expect(policy_for(admin_user).staff?).to be true
      end

      it 'returns false for students' do
        expect(policy_for(student_user).staff?).to be false
      end

      it 'returns false for unenrolled users' do
        expect(policy_for(unenrolled_user).staff?).to be false
      end
    end

    describe '#student?' do
      it 'returns true for students' do
        expect(policy_for(student_user).student?).to be true
      end

      it 'returns false for staff' do
        expect(policy_for(ta_user).student?).to be false
        expect(policy_for(teacher_user).student?).to be false
      end
    end

    describe '#enrolled?' do
      it 'returns true for enrolled users' do
        expect(policy_for(student_user).enrolled?).to be true
        expect(policy_for(ta_user).enrolled?).to be true
      end

      it 'returns false for unenrolled users' do
        expect(policy_for(unenrolled_user).enrolled?).to be false
      end
    end

    describe '#view_role' do
      it 'returns instructor for all staff roles' do
        expect(policy_for(teacher_user).view_role).to eq('instructor')
        expect(policy_for(leadta_user).view_role).to eq('instructor')
        expect(policy_for(ta_user).view_role).to eq('instructor')
      end

      it 'returns student for students' do
        expect(policy_for(student_user).view_role).to eq('student')
      end

      it 'returns nil for unenrolled users' do
        expect(policy_for(unenrolled_user).view_role).to be_nil
      end
    end
  end

  describe 'course-level permissions' do
    describe '#can_view_import_page?' do
      it 'allows any authenticated user' do
        expect(policy_for(student_user).can_view_import_page?).to be true
        expect(policy_for(unenrolled_user).can_view_import_page?).to be true
      end

      it 'disallows nil user' do
        expect(CoursePolicy.new(nil, course).can_view_import_page?).to be false
      end
    end

    describe '#can_create_course?' do
      it 'allows any authenticated user' do
        expect(policy_for(student_user).can_create_course?).to be true
        expect(policy_for(ta_user).can_create_course?).to be true
      end
    end

    describe '#can_view_course?' do
      it 'allows enrolled users' do
        expect(policy_for(student_user).can_view_course?).to be true
        expect(policy_for(ta_user).can_view_course?).to be true
      end

      it 'allows site admins even if not enrolled' do
        expect(policy_for(admin_user).can_view_course?).to be true
      end

      it 'disallows unenrolled non-admin users' do
        expect(policy_for(unenrolled_user).can_view_course?).to be false
      end
    end

    describe '#can_edit_course?' do
      it 'allows teachers' do
        expect(policy_for(teacher_user).can_edit_course?).to be true
      end

      it 'allows lead TAs' do
        expect(policy_for(leadta_user).can_edit_course?).to be true
      end

      it 'allows site admins' do
        expect(policy_for(admin_user).can_edit_course?).to be true
      end

      it 'disallows regular TAs' do
        expect(policy_for(ta_user).can_edit_course?).to be false
      end

      it 'disallows students' do
        expect(policy_for(student_user).can_edit_course?).to be false
      end
    end

    describe '#can_delete_course?' do
      it 'allows course admins' do
        expect(policy_for(teacher_user).can_delete_course?).to be true
        expect(policy_for(leadta_user).can_delete_course?).to be true
      end

      it 'disallows regular TAs' do
        expect(policy_for(ta_user).can_delete_course?).to be false
      end

      it 'disallows students' do
        expect(policy_for(student_user).can_delete_course?).to be false
      end
    end

    describe '#can_view_enrollments?' do
      it 'allows all staff' do
        expect(policy_for(teacher_user).can_view_enrollments?).to be true
        expect(policy_for(leadta_user).can_view_enrollments?).to be true
        expect(policy_for(ta_user).can_view_enrollments?).to be true
      end

      it 'disallows students' do
        expect(policy_for(student_user).can_view_enrollments?).to be false
      end
    end

    describe '#can_sync_assignments?' do
      it 'allows all staff' do
        expect(policy_for(teacher_user).can_sync_assignments?).to be true
        expect(policy_for(ta_user).can_sync_assignments?).to be true
      end

      it 'disallows students' do
        expect(policy_for(student_user).can_sync_assignments?).to be false
      end
    end

    describe '#can_sync_enrollments?' do
      it 'allows all staff' do
        expect(policy_for(teacher_user).can_sync_enrollments?).to be true
        expect(policy_for(ta_user).can_sync_enrollments?).to be true
      end

      it 'disallows students' do
        expect(policy_for(student_user).can_sync_enrollments?).to be false
      end
    end
  end

  describe 'request permissions' do
    describe '#can_view_requests?' do
      it 'allows enrolled users' do
        expect(policy_for(student_user).can_view_requests?).to be true
        expect(policy_for(ta_user).can_view_requests?).to be true
      end

      it 'allows site admins' do
        expect(policy_for(admin_user).can_view_requests?).to be true
      end

      it 'disallows unenrolled users' do
        expect(policy_for(unenrolled_user).can_view_requests?).to be false
      end
    end

    describe '#can_create_request?' do
      it 'allows enrolled users' do
        expect(policy_for(student_user).can_create_request?).to be true
        expect(policy_for(ta_user).can_create_request?).to be true
      end
    end

    describe '#can_create_request_for_student?' do
      it 'allows staff' do
        expect(policy_for(teacher_user).can_create_request_for_student?).to be true
        expect(policy_for(ta_user).can_create_request_for_student?).to be true
      end

      it 'disallows students' do
        expect(policy_for(student_user).can_create_request_for_student?).to be false
      end
    end

    describe '#can_cancel_request?' do
      it 'allows all staff' do
        expect(policy_for(teacher_user).can_cancel_request?).to be true
        expect(policy_for(leadta_user).can_cancel_request?).to be true
        expect(policy_for(ta_user).can_cancel_request?).to be true
      end

      it 'allows site admins' do
        expect(policy_for(admin_user).can_cancel_request?).to be true
      end

      it 'disallows students' do
        expect(policy_for(student_user).can_cancel_request?).to be false
      end
    end

    describe '#can_approve_or_deny_requests?' do
      it 'allows all staff including regular TAs' do
        expect(policy_for(teacher_user).can_approve_or_deny_requests?).to be true
        expect(policy_for(leadta_user).can_approve_or_deny_requests?).to be true
        expect(policy_for(ta_user).can_approve_or_deny_requests?).to be true
      end

      it 'allows site admins' do
        expect(policy_for(admin_user).can_approve_or_deny_requests?).to be true
      end

      it 'disallows students' do
        expect(policy_for(student_user).can_approve_or_deny_requests?).to be false
      end
    end
  end

  describe 'settings permissions (course admin only)' do
    describe '#can_manage_settings?' do
      it 'allows teachers' do
        expect(policy_for(teacher_user).can_manage_settings?).to be true
      end

      it 'allows lead TAs' do
        expect(policy_for(leadta_user).can_manage_settings?).to be true
      end

      it 'allows site admins' do
        expect(policy_for(admin_user).can_manage_settings?).to be true
      end

      it 'disallows regular TAs' do
        expect(policy_for(ta_user).can_manage_settings?).to be false
      end

      it 'disallows students' do
        expect(policy_for(student_user).can_manage_settings?).to be false
      end
    end

    describe '#can_manage_form_settings?' do
      it 'allows course admins only' do
        expect(policy_for(teacher_user).can_manage_form_settings?).to be true
        expect(policy_for(leadta_user).can_manage_form_settings?).to be true
        expect(policy_for(ta_user).can_manage_form_settings?).to be false
        expect(policy_for(student_user).can_manage_form_settings?).to be false
      end
    end

    describe '#can_manage_extended_circumstances?' do
      it 'allows course admins only' do
        expect(policy_for(teacher_user).can_manage_extended_circumstances?).to be true
        expect(policy_for(leadta_user).can_manage_extended_circumstances?).to be true
        expect(policy_for(ta_user).can_manage_extended_circumstances?).to be false
        expect(policy_for(student_user).can_manage_extended_circumstances?).to be false
      end
    end

    describe '#can_toggle_assignment?' do
      it 'allows course admins only' do
        expect(policy_for(teacher_user).can_toggle_assignment?).to be true
        expect(policy_for(leadta_user).can_toggle_assignment?).to be true
        expect(policy_for(ta_user).can_toggle_assignment?).to be false
        expect(policy_for(student_user).can_toggle_assignment?).to be false
      end
    end
  end

  describe 'without a course' do
    it 'handles nil course gracefully' do
      policy = CoursePolicy.new(student_user, nil)
      expect(policy.enrolled?).to be false
      expect(policy.staff?).to be false
      expect(policy.can_view_import_page?).to be true
    end
  end
end
