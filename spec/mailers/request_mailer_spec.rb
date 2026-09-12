require 'rails_helper'

RSpec.describe RequestMailer do
  let(:course) { create(:course, canvas_id: 'req_mailer_1', course_name: 'Software Engineering', course_code: 'CS169') }
  let(:student) { create(:user, canvas_uid: 'req_mailer_stu', email: 'student@example.com', name: 'Alice <Student>') }
  let(:assignment) do
    Assignment.create!(
      name: 'Project 1',
      course_to_lms: CourseToLms.create!(course: course, lms: Lms.first, external_course_id: 'ext_req_mailer'),
      due_date: Time.zone.parse('2026-09-10 23:59'),
      external_assignment_id: 'asgn_req_mailer',
      enabled: true
    )
  end
  let(:request) do
    Request.create!(course: course, assignment: assignment, user: student, status: 'pending',
                    reason: 'Sick & tired', requested_due_date: Time.zone.parse('2026-09-12 23:59'))
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('DEFAULT_FROM_EMAIL').and_return('flextensions@berkeley.edu')
  end

  describe '#submission_confirmation', app_origin: 'https://flextensions.example.com' do
    it 'addresses the student from the default sender' do
      mail = described_class.submission_confirmation(request)

      expect(mail.to).to eq([ 'student@example.com' ])
      expect(mail.from).to eq([ 'flextensions@berkeley.edu' ])
      expect(mail.reply_to).to eq([ 'flextensions@berkeley.edu' ])
      expect(mail.subject).to eq('Extension Request Received: Project 1 - CS169')
    end

    it 'describes the pending request in the HTML part, escaping user content' do
      html = described_class.submission_confirmation(request).html_part.body.decoded

      expect(html).to include('Hello Alice &lt;Student&gt;,')
      expect(html).to include('Course staff will review it')
      expect(html).to include('Pending review')
      expect(html).to include('Thu, Sep 10, 2026 11:59 PM')
      expect(html).to include('Sick &amp; tired')
      expect(html).to include("https://flextensions.example.com/courses/#{course.id}/requests/#{request.id}")
      expect(html).to include('If you have any questions, please contact your course staff.')
    end

    it 'wraps the message in the shared layout with the course and a button' do
      html = described_class.submission_confirmation(request).html_part.body.decoded

      expect(html).to include('CS169 | Flextensions')
      expect(html).to include('View Your Request')
      expect(html).to include('<strong>Status:</strong> Pending review')
      expect(html).not_to include('<table')
    end

    it 'renders a plain-text part with the same details' do
      mail = described_class.submission_confirmation(request)

      text = mail.text_part.body.decoded
      expect(text).to include('Hello Alice <Student>,')
      expect(text).to include('Status: Pending review')
      expect(text).to include('Reason: Sick & tired')
      expect(text).to include("View Your Request: https://flextensions.example.com/courses/#{course.id}/requests/#{request.id}")
    end

    it 'uses the course reply email and invites replies when one is set' do
      course.course_settings.update!(reply_email: 'staff@example.com')

      mail = described_class.submission_confirmation(request)

      expect(mail.reply_to).to eq([ 'staff@example.com' ])
      expect(mail.html_part.body.decoded).to include('Reply to this email to reach your course staff.')
    end

    it 'says the request was approved automatically when it already is' do
      request.update!(status: 'approved', auto_approved: true)

      html = described_class.submission_confirmation(request).html_part.body.decoded

      expect(html).to include('approved automatically')
      expect(html).to include('Approved')
      expect(html).not_to include('edit or cancel this request')
    end
  end
end
