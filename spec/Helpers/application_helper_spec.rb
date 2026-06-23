require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#sidebar_section' do
    def section_for(controller, action)
      allow(helper).to receive_messages(controller_name: controller, action_name: action)
      helper.sidebar_section
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
end
