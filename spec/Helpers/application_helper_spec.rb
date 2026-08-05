require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#copy_to_clipboard_button' do
    it 'wires the button up to the clipboard Stimulus controller' do
      button = helper.copy_to_clipboard_button('student1@example.com')

      expect(button).to include('type="button"')
      expect(button).to include('data-controller="clipboard"')
      # `>` is escaped in the rendered attribute value.
      expect(button).to include('data-action="click-&gt;clipboard#copy"')
      expect(button).to include('data-clipboard-text-value="student1@example.com"')
      expect(button).to include('<i class="fas fa-clipboard"')
    end

    it 'uses the label as both the tooltip and the accessible name' do
      button = helper.copy_to_clipboard_button('a@b.com', label: 'Copy email address for User 3')

      expect(button).to include('title="Copy email address for User 3"')
      expect(button).to include('aria-label="Copy email address for User 3"')
      # The icon is decorative, so the label is the button's only accessible name.
      expect(button).to include('aria-hidden="true"')
    end

    it 'escapes the copied text so it cannot break out of the attribute' do
      button = helper.copy_to_clipboard_button(%(evil" onclick="alert(1)))

      expect(button).to include('data-clipboard-text-value="evil&quot; onclick=&quot;alert(1)"')
      expect(button).not_to include('onclick="alert(1)"')
    end
  end

  describe '#deployment_note' do
    let(:deployed_at) { Time.zone.local(2026, 8, 5, 10, 30) }
    let(:sha) { 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2' }

    it 'renders the deploy time and a link to the commit' do
      allow(DeploymentInfo).to receive_messages(
        deployed_at: deployed_at,
        short_commit: 'a1b2c3d',
        commit_url: "https://github.com/berkeley-cdss/flextensions/commit/#{sha}"
      )

      note = helper.deployment_note

      expect(note).to include('Last updated Aug 5, 2026 at 10:30 AM')
      expect(note).to include(%(<time datetime="#{deployed_at.iso8601}"))
      expect(note).to include(%(href="https://github.com/berkeley-cdss/flextensions/commit/#{sha}"))
      expect(note).to include('a1b2c3d')
    end

    it 'renders just the timestamp when the commit is unknown' do
      allow(DeploymentInfo).to receive_messages(deployed_at: deployed_at, short_commit: nil, commit_url: nil)

      note = helper.deployment_note

      expect(note).to include('Last updated Aug 5, 2026 at 10:30 AM')
      expect(note).not_to include('<a ')
    end

    it 'is nil when nothing about the deployment is known' do
      allow(DeploymentInfo).to receive_messages(deployed_at: nil, short_commit: nil, commit_url: nil)

      expect(helper.deployment_note).to be_nil
    end
  end
end
