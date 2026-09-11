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
    @body_html = self.class.html_with_line_breaks(body).html_safe
    # rubocop:enable Rails/OutputSafety
    @body_text = self.class.html_to_text(body)

    mail(to: to, cc: cc, from: from, reply_to: reply_to, subject: subject)
  end

  # Turns the template's newlines into <br> tags, leaving <table> blocks (such
  # as {{request_details_table}}) untouched so a line break never lands inside
  # their markup.
  def self.html_with_line_breaks(html)
    html.split(%r{(<table\b.*?</table>)}mi).each_with_index.map do |segment, index|
      index.odd? ? segment : segment.gsub("\n", "<br>\n")
    end.join
  end

  # Plain-text rendering of a template body for the text part. Table rows
  # become "Label: value" lines (see {{request_details_table}}), other markup
  # is stripped and entities are decoded.
  def self.html_to_text(html)
    text = html
      .gsub(%r{</t[dh]>\s*<t[dh][^>]*>}i, ': ')
      .gsub(%r{\s*<tr[^>]*>\s*}i, '')
      .gsub(%r{\s*</table>\s*}i, '')
      .gsub(%r{\s*<table[^>]*>\s*}i, "\n")
      .gsub(%r{\s*</tr>\s*}i, "\n")
      .gsub(%r{<br\s*/?>\s*\n?}i, "\n")
    text = CGI.unescapeHTML(ActionController::Base.helpers.strip_tags(text))
    text.lines.map(&:strip).join("\n").gsub(/\n{3,}/, "\n\n").strip
  end
end
