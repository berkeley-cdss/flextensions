require 'rails_helper'

RSpec.describe PendingRequestsMailer do
  let(:course) do
    create(:course, canvas_id: 'mailer_123', course_name: 'CS 101', course_code: 'CS101', semester: 'Spring 2026')
  end
  let(:course_settings) { course.course_settings }
  let(:lms) { Lms.first }
  let(:course_to_lms) { CourseToLms.create!(course: course, lms: lms, external_course_id: 'ext_mailer_123') }
  let(:assignment) do
    Assignment.create!(
      name: 'HW1',
      course_to_lms: course_to_lms,
      due_date: 3.days.from_now,
      external_assignment_id: 'asgn_mailer_1',
      enabled: true
    )
  end

  before do
    course_settings.update!(pending_notification_frequency: 'daily', pending_notification_email: 'prof@example.com')
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('DEFAULT_FROM_EMAIL').and_return('flextensions@berkeley.edu')
  end

  def create_pending_request(name:, uid:)
    Request.create!(course: course, assignment: assignment, status: 'pending',
                    reason: 'Need time', requested_due_date: 5.days.from_now,
                    user: create(:user, canvas_uid: uid, email: "#{uid}@example.com", name: name))
  end

  def build_mail(pending_requests, auto_approved_count: 0, frequency: 'daily')
    described_class.pending_requests_email(
      course_settings: course_settings,
      pending_requests: pending_requests,
      auto_approved_count: auto_approved_count,
      frequency: frequency
    )
  end

  describe '#pending_requests_email', app_origin: 'https://flextensions.example.com' do
    it 'uses the reply email when set and links to the request' do
      course_settings.update!(reply_email: 'staff@example.com')
      request = create_pending_request(name: 'Alice', uid: 'mailer_stu_1')

      mail = build_mail([ request ])

      expect(mail.from).to eq([ 'flextensions@berkeley.edu' ])
      expect(mail.reply_to).to eq([ 'staff@example.com' ])
      expect(mail.subject).to eq('1 Pending Extension Request - CS101')
      expect(mail.html_part.body.decoded)
        .to include("https://flextensions.example.com/courses/#{course.id}/requests/#{request.id}")
    end

    it 'words the auto-approval window per frequency and singular count' do
      request = create_pending_request(name: 'Alice', uid: 'mailer_stu_1')

      mail = build_mail([ request ], auto_approved_count: 1, frequency: 'weekly')

      expect(mail.html_part.body.decoded).to include('In the past week 1 request')
      expect(mail.html_part.body.decoded).to include('has been auto approved.')
    end

    it 'falls back to a placeholder for users without a name' do
      request = create_pending_request(name: nil, uid: 'mailer_stu_1')

      mail = build_mail([ request ])

      expect(mail.html_part.body.decoded).to include('Unknown student, HW1, 2 days')
    end

    it 'caps the per-request list and links to the requests page for the rest' do
      stub_const('PendingRequestsMailer::MAX_LISTED_REQUESTS', 2)
      requests = 3.times.map { |i| create_pending_request(name: "Student #{i}", uid: "mailer_stu_#{i}") }

      mail = build_mail(requests)

      html = mail.html_part.body.decoded
      expect(html).to include('Student 0')
      expect(html).to include('Student 1')
      expect(html).not_to include('Student 2')
      expect(html).to include('and 1 more')
      expect(mail.text_part.body.decoded).to include('and 1 more')
    end
  end
end
