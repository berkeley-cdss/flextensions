# frozen_string_literal: true

# A class for sending templated emails, using basic `{{variable}}` substitution.
# TODO: Migrate this 'Service' to the ApplicationMailer class.
# As of Rails 8.1 we needed to introduct a subclass of ActionMailer::Base.
# We should be able to deprecate this class and move the render_templates method to the FlextensionsMailer class.

class EmailService
  class << self
    # Given a subject_template and body_template (both strings
    # containing {{variable}} placeholders) plus a mapping
    # (e.g. { "student_name" => "Yaman", ... }),
    # returns a hash with :subject and :body filled in.
    def render_templates(subject_template, body_template, mapping)
      mapping.each_with_object(
        { subject: subject_template.dup, body: body_template.dup }
      ) do |(key, val), memo|
        placeholder = /{{\s*#{key}\s*}}/i
        memo[:subject].gsub!(placeholder, val.to_s)
        memo[:body].gsub!(placeholder, val.to_s)
      end
    end

    # Sends email now (or .deliver_later if you pass deliver_later: true).
    #
    # to:               recipient email
    # from:             sender   email
    # subject_template: e.g. "Extension for {{student_name}}"
    # body_template:    e.g.  course_settings.email_template
    # mapping:          { "student_name" => "Yaman", ... }
    def send_email(to:, from:, reply_to:, subject_template:, body_template:, mapping:, deliver_later: false)
      rendered = render_templates(subject_template, body_template, mapping)

      mail = ApplicationMailer.generic_email(
        to: to,
        from: from,
        reply_to: reply_to,
        subject: rendered[:subject],
        body: rendered[:body].gsub("\n", "<br>\n"),
      )

      deliver_later ? mail.deliver_later : mail.deliver_now
    end
  end
end
