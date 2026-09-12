# frozen_string_literal: true

# Delivers an email whose subject and body were written by course staff and
# already interpolated by EmailService. The body is plain text with optional
# inline HTML (interpolated values are pre-escaped), so it is wrapped in the
# shared mailer layout with newlines turned into line breaks, plus a text part
# for clients that do not render HTML.
class TemplatedMailer < ApplicationMailer
  def templated_email(to:, from:, reply_to:, subject:, body:, cc: nil, course: nil, cta_label: nil, cta_url: nil)
    @course = course
    @cta_label = cta_label
    @cta_url = cta_url
    # rubocop:disable Rails/OutputSafety -- values were escaped in EmailService; any
    # remaining markup was written by course staff in their own template.
    @body_html = body.gsub("\n", "<br>\n").html_safe
    # rubocop:enable Rails/OutputSafety
    @body_text = self.class.html_to_text(body)

    mail(to: to, cc: cc, from: from, reply_to: reply_to, subject: subject)
  end

  # Plain-text rendering of a template body for the text part: markup is
  # stripped and entities are decoded.
  def self.html_to_text(html)
    text = html.gsub(%r{<br\s*/?>\s*\n?}i, "\n")
    text = CGI.unescapeHTML(ActionController::Base.helpers.strip_tags(text))
    text.lines.map(&:strip).join("\n").gsub(/\n{3,}/, "\n\n").strip
  end
end
