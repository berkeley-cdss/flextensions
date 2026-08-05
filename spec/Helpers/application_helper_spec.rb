require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#current_nav_page' do
    def section_for(controller, action)
      allow(helper).to receive_messages(controller_name: controller, action_name: action)
      helper.current_nav_page
    end

    it 'maps course and settings pages to their sidebar keys' do
      expect(section_for('courses', 'show')).to eq('show')
      expect(section_for('courses', 'edit')).to eq('course_details')
      expect(section_for('courses', 'update')).to eq('course_details')
      expect(section_for('courses', 'enrollments')).to eq('enrollments')
      expect(section_for('course_settings', 'approvals')).to eq('approvals')
      expect(section_for('course_settings', 'emails')).to eq('emails')
      expect(section_for('form_settings', 'edit')).to eq('form_settings')
      expect(section_for('form_settings', 'update')).to eq('form_settings')
    end

    it 'distinguishes new-request pages from the requests list' do
      expect(section_for('requests', 'new')).to eq('form')
      expect(section_for('requests', 'new_for_student')).to eq('form')
      expect(section_for('requests', 'index')).to eq('requests')
      expect(section_for('requests', 'show')).to eq('requests')
    end

    it 'returns nil for pages without a sidebar entry' do
      expect(section_for('home', 'index')).to be_nil
    end
  end

  describe '#sidebar_nav_item' do
    before { allow(helper).to receive_messages(controller_name: 'courses', action_name: 'show') }

    it 'renders an active link for the current page' do
      html = helper.sidebar_nav_item(path: '/x', icon: 'fas fa-tasks', nav: 'show', text: 'Assignments')

      expect(html).to include('nav-link d-flex align-items-center active')
      expect(html).to include('aria-current="page"')
      expect(html).to include('fas fa-tasks')
      expect(html).to include('Assignments')
    end

    it 'renders an inactive link for other pages' do
      html = helper.sidebar_nav_item(path: '/x', icon: 'fas fa-users', nav: 'enrollments', text: 'Enrollments')

      expect(html).to include('link-body-emphasis')
      expect(html).not_to include('active')
      expect(html).not_to include('aria-current')
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
