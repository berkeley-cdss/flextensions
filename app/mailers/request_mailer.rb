# frozen_string_literal: true

# Emails sent to the student who owns an extension request. Rendered from ERB
# views in app/views/request_mailer/, unlike the staff-editable approval and
# denial emails (see TemplatedMailer).
class RequestMailer < ApplicationMailer
  # Receipt sent to the student as soon as a request is submitted, whether by
  # the student or by course staff on their behalf.
  def submission_confirmation(request)
    @request = request
    @course = request.course
    @student = request.user
    @assignment = request.assignment
    @reply_email = @course.course_settings.reply_email.presence
    @cta_label = 'View Your Request'
    @cta_url = request.request_link

    default_from = ENV.fetch('DEFAULT_FROM_EMAIL')
    mail(
      to: @student.email,
      from: default_from,
      reply_to: @reply_email || default_from,
      subject: "Extension Request Received: #{@assignment.name} - #{@course.course_code}"
    )
  end
end
