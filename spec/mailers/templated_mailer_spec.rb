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

  it 'wraps the body in the shared HTML layout with line breaks', app_origin: 'https://flextensions.example.com' do
    mail = build_mail(course: course, cta_label: 'View Request', cta_url: 'https://flextensions.example.com/r/1')

    html = mail.html_part.body.decoded
    expect(html).to include("Hello Alice,<br>\nYour request was &lt;approved&gt;.<br>\n<b>Enjoy!</b>")
    expect(html).to include('CS61B | Flextensions')
    expect(html).to include('href="https://flextensions.example.com/r/1"')
    expect(html).to include('View Request')
    expect(html).to include('https://flextensions.example.com/assets/uc-berkeley-logo')
    expect(html).to include('href="https://docs.flextensions.berkeley.edu"')
    expect(html).not_to include('<table')
    expect(mail.reply_to).to eq([ 'staff@example.com' ])
  end

  it 'copies the cc address when given' do
    mail = build_mail(cc: 'staff@example.com')

    expect(mail.cc).to eq([ 'staff@example.com' ])
  end

  it 'renders a plain-text part with markup stripped and entities decoded' do
    mail = build_mail

    text = mail.text_part.body.decoded
    expect(text).to include("Hello Alice,\nYour request was <approved>.\nEnjoy!")
    expect(text).not_to include('<b>')
    expect(text).to include('Get Help: https://docs.flextensions.berkeley.edu')
  end

  it 'turns {{request_details_table}} lines into plain label/value lines in the text part' do
    mail = build_mail(body: "Hello,\n<strong>Status:</strong> Approved\n<strong>Reason:</strong> Sick &amp; tired\nThanks")

    expect(mail.text_part.body.decoded).to include("Hello,\nStatus: Approved\nReason: Sick & tired\nThanks")
  end

  it 'omits the course code and button when not given' do
    html = build_mail.html_part.body.decoded

    expect(html).to include('>Flextensions<').or include("\n        Flextensions\n")
    expect(html).not_to include(' | Flextensions')
    expect(html).not_to include('Open Flextensions')
  end
end
