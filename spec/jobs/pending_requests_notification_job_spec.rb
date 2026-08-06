require 'rails_helper'

RSpec.describe PendingRequestsNotificationJob, type: :job do
  let(:course) do
    create(:course, canvas_id: 'notif_123', course_name: 'CS 101', course_code: 'CS101', semester: 'Spring 2026')
  end
  let(:student) { create(:user, canvas_uid: 'stu_notif_1', email: 'student_notif@example.com', name: 'Student') }
  let(:lms) { Lms.first }
  let(:course_to_lms) { CourseToLms.create!(course: course, lms: lms, external_course_id: 'ext_123') }
  let(:assignment) do
    Assignment.create!(
      name: 'HW1',
      course_to_lms: course_to_lms,
      due_date: 3.days.from_now,
      external_assignment_id: 'asgn_notif_1',
      enabled: true
    )
  end

  before do
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.deliveries.clear
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('DEFAULT_FROM_EMAIL').and_return('flextensions@berkeley.edu')
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('APP_HOST').and_return('http://localhost:3000')
  end

  def mail_bodies
    mail = ActionMailer::Base.deliveries.last
    [ mail.html_part.body.decoded, mail.text_part.body.decoded ]
  end

  describe '#perform' do
    it 'sends email when course has matching frequency and pending requests' do
      course.course_settings.update!(pending_notification_frequency: 'daily', pending_notification_email: 'prof@example.com')
      request = Request.create!(course: course, assignment: assignment, user: student, status: 'pending',
                                reason: 'Need more time', requested_due_date: 5.days.from_now)

      expect { described_class.perform_now('daily') }.to change { ActionMailer::Base.deliveries.count }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ 'prof@example.com' ])
      expect(mail.subject).to include('1 Pending Extension Request')
      expect(mail.subject).to include('CS101')

      expect(mail_bodies).to all include(
        "http://localhost:3000/courses/#{course.id}",
        "http://localhost:3000/courses/#{course.id}/requests",
        "http://localhost:3000/courses/#{course.id}/requests/#{request.id}",
        'CS 101, Spring 2026',
        'Student, HW1, 2 days',
        'In the past day 0 requests have been auto approved.'
      )
    end

    it 'counts recent auto-approvals within the frequency window' do
      course.course_settings.update!(pending_notification_frequency: 'daily', pending_notification_email: 'prof@example.com')
      Request.create!(course: course, assignment: assignment, user: student, status: 'pending',
                      reason: 'Need more time', requested_due_date: 5.days.from_now)

      recent_user = create(:user, canvas_uid: 'stu_notif_auto1', email: 'auto1@example.com')
      Request.create!(course: course, assignment: assignment, user: recent_user, status: 'approved',
                      auto_approved: true, reason: 'Auto', requested_due_date: 4.days.from_now)
      stale_user = create(:user, canvas_uid: 'stu_notif_auto2', email: 'auto2@example.com')
      travel_to(2.days.ago) do
        Request.create!(course: course, assignment: assignment, user: stale_user, status: 'approved',
                        auto_approved: true, reason: 'Auto', requested_due_date: 4.days.from_now)
      end

      described_class.perform_now('daily')

      expect(mail_bodies).to all include('In the past day 1 request has been auto approved.')
    end

    it 'sends email to courses set to hourly and words the window accordingly' do
      course.course_settings.update!(pending_notification_frequency: 'hourly', pending_notification_email: 'prof@example.com')
      Request.create!(course: course, assignment: assignment, user: student, status: 'pending',
                      reason: 'Need more time', requested_due_date: 5.days.from_now)

      expect { described_class.perform_now('hourly') }.to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(ActionMailer::Base.deliveries.last.to).to eq([ 'prof@example.com' ])
      expect(mail_bodies).to all include('In the past hour 0 requests have been auto approved.')
    end

    it 'does not send hourly digests to courses set to another frequency' do
      course.course_settings.update!(pending_notification_frequency: 'daily', pending_notification_email: 'prof@example.com')
      Request.create!(course: course, assignment: assignment, user: student, status: 'pending',
                      reason: 'Need more time', requested_due_date: 5.days.from_now)

      expect { described_class.perform_now('hourly') }.not_to(change { ActionMailer::Base.deliveries.count })
    end

    it 'skips courses with zero pending requests' do
      course.course_settings.update!(pending_notification_frequency: 'daily', pending_notification_email: 'prof@example.com')

      expect { described_class.perform_now('daily') }.not_to(change { ActionMailer::Base.deliveries.count })
    end

    it 'only sends to courses matching the given frequency' do
      course.course_settings.update!(pending_notification_frequency: 'weekly', pending_notification_email: 'prof@example.com')
      Request.create!(course: course, assignment: assignment, user: student, status: 'pending',
                      reason: 'Need more time', requested_due_date: 5.days.from_now)

      expect { described_class.perform_now('daily') }.not_to(change { ActionMailer::Base.deliveries.count })
    end

    it 'pluralizes correctly and lists each pending request' do
      course.course_settings.update!(pending_notification_frequency: 'daily', pending_notification_email: 'prof@example.com')
      requests = 2.times.map do |i|
        Request.create!(course: course, assignment: assignment,
                        user: create(:user, canvas_uid: "stu_multi_#{i}", email: "stu_multi_#{i}@example.com",
                                            name: "Student #{i}"),
                        status: 'pending', reason: 'Need time', requested_due_date: 5.days.from_now)
      end

      described_class.perform_now('daily')

      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to include('2 Pending Extension Requests')
      expected_lines = requests.flat_map do |request|
        [ "#{request.user.name}, HW1, 2 days",
          "http://localhost:3000/courses/#{course.id}/requests/#{request.id}" ]
      end
      expect(mail_bodies).to all include(*expected_lines)
    end

    it 'sends separate emails to multiple courses' do
      course.course_settings.update!(pending_notification_frequency: 'daily', pending_notification_email: 'prof1@example.com')
      Request.create!(course: course, assignment: assignment, user: student, status: 'pending',
                      reason: 'Need time', requested_due_date: 5.days.from_now)

      other_course = create(:course, canvas_id: 'notif_456', course_name: 'CS 201', course_code: 'CS201')
      other_ctlms = CourseToLms.create!(course: other_course, lms: lms, external_course_id: 'ext_456')
      other_assignment = Assignment.create!(name: 'HW2', course_to_lms: other_ctlms, due_date: 3.days.from_now,
                                            external_assignment_id: 'asgn_notif_2', enabled: true)
      other_course.course_settings.update!(pending_notification_frequency: 'daily', pending_notification_email: 'prof2@example.com')
      other_student = create(:user, canvas_uid: 'stu_notif_2', email: 'stu_notif_2@example.com')
      Request.create!(course: other_course, assignment: other_assignment, user: other_student, status: 'pending',
                      reason: 'Need time', requested_due_date: 5.days.from_now)

      expect { described_class.perform_now('daily') }.to change { ActionMailer::Base.deliveries.count }.by(2)
    end
  end
end
