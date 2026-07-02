# spec/mailers/staging_email_interceptor_spec.rb
require 'rails_helper'

RSpec.describe StagingEmailInterceptor do
  def build_message(to:, subject:, cc: nil, bcc: nil)
    Mail.new do
      to to
      cc cc if cc
      bcc bcc if bcc
      from 'flextensions@berkeley.edu'
      subject subject
      body 'Hello'
    end
  end

  it 'redirects the recipient to the default staging mailbox' do
    message = build_message(to: 'student@example.com', subject: 'Your extension')
    described_class.delivering_email(message)

    expect(message.to).to eq([ described_class::DEFAULT_OVERRIDE ])
  end

  it 'honors STAGING_EMAIL_OVERRIDE when set' do
    message = build_message(to: 'student@example.com', subject: 'Your extension')

    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch)
      .with('STAGING_EMAIL_OVERRIDE', described_class::DEFAULT_OVERRIDE)
      .and_return('someone@example.com')

    described_class.delivering_email(message)

    expect(message.to).to eq([ 'someone@example.com' ])
  end

  it 'preserves the original recipient(s) in the subject line' do
    message = build_message(to: %w[a@example.com b@example.com], subject: 'Your extension')
    described_class.delivering_email(message)

    expect(message.subject).to eq('[STAGING -> a@example.com, b@example.com] Your extension')
  end

  it 'strips cc and bcc so no real person is reached' do
    message = build_message(
      to: 'student@example.com',
      subject: 'Your extension',
      cc: 'ta@example.com',
      bcc: 'instructor@example.com'
    )
    described_class.delivering_email(message)

    expect(message.cc).to be_nil
    expect(message.bcc).to be_nil
  end
end
