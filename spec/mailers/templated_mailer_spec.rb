require 'rails_helper'

RSpec.describe TemplatedMailer do
  let(:course) { create(:course, canvas_id: 'tmpl_mailer_1', course_name: 'Data Structures', course_code: 'CS61B') }

  def build_mail(**overrides)
    described_class.templated_email(
      **{
        to: 'student@example.com',
        from: 'flextensions@berkeley.edu',
        reply_to: 'staff@example.com',
        subject: 'Approved',
        body: "Hello Alice,\nYour request was &lt;approved&gt;.\n<b>Enjoy!</b>"
      }.merge(overrides)
    )
  end

  it 'wraps the body in the shared HTML layout with line breaks' do
    mail = build_mail(course: course, cta_label: 'View Request', cta_url: 'https://flextensions.example.com/r/1')

    html = mail.html_part.body.decoded
    expect(html).to include("Hello Alice,<br>\nYour request was &lt;approved&gt;.<br>\n<b>Enjoy!</b>")
    expect(html).to include('CS61B &middot; Data Structures')
    expect(html).to include('href="https://flextensions.example.com/r/1"')
    expect(html).to include('View Request')
    expect(mail.reply_to).to eq([ 'staff@example.com' ])
  end

  it 'renders a plain-text part with markup stripped and entities decoded' do
    mail = build_mail

    text = mail.text_part.body.decoded
    expect(text).to include("Hello Alice,\nYour request was <approved>.\nEnjoy!")
    expect(text).not_to include('<b>')
  end

  it 'does not insert line breaks inside a multi-line table' do
    table = "<table width=\"100%\"\n       style=\"font-size:15px;\">\n  <tr>\n    <td>Status</td>\n    <td>Approved</td>\n  </tr>\n</table>"
    mail = build_mail(body: "Hello,\n#{table}\nThanks")

    html = mail.html_part.body.decoded
    expect(html).to include("Hello,<br>\n#{table}<br>\nThanks")
    expect(html.scan('<br>').size).to eq(2)
  end

  it 'turns a details table into label/value lines in the text part' do
    table = '<table><tr><td style="x">Status</td><td>Approved</td></tr>' \
            "<tr>\n  <td>Reason</td>\n  <td>Sick &amp; tired</td>\n</tr></table>"
    mail = build_mail(body: "Hello,\n#{table}\nThanks")

    expect(mail.text_part.body.decoded).to include("Hello,\nStatus: Approved\nReason: Sick & tired\nThanks")
  end

  it 'omits the course line and button when not given' do
    html = build_mail.html_part.body.decoded

    expect(html).not_to include('&middot;')
    expect(html).not_to include('Open Flextensions')
  end
end
