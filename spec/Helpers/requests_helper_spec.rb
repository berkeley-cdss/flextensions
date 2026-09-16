require 'rails_helper'

RSpec.describe RequestsHelper, type: :helper do
  let(:course) { create(:course) }
  let(:canvas) { Lms.find_by(id: 1) || create(:lms, :canvas) }
  let(:gradescope) { Lms.find_by(id: 2) || create(:lms, :gradescope) }
  let(:canvas_link) { create(:course_to_lms, course: course, lms: canvas) }
  let(:gradescope_link) { create(:course_to_lms, course: course, lms: gradescope) }

  describe '#assignment_option_label' do
    let(:assignment) { create(:assignment, name: 'Homework 1', course_to_lms: gradescope_link, enabled: true) }

    it 'returns the plain name when no other assignment shares it' do
      expect(helper.assignment_option_label(assignment, Set.new)).to eq('Homework 1')
    end

    it 'appends the LMS name when the name is duplicated in the course' do
      expect(helper.assignment_option_label(assignment, Set['Homework 1'])).to eq('Homework 1 [Gradescope]')
    end
  end

  describe '#assignment_select_options' do
    let!(:canvas_hw) { create(:assignment, name: 'Homework 1', course_to_lms: canvas_link, enabled: true) }
    let!(:gradescope_hw) { create(:assignment, name: 'Homework 1', course_to_lms: gradescope_link, enabled: true) }
    let!(:project) { create(:assignment, name: 'Project', course_to_lms: canvas_link, enabled: true) }

    it 'disambiguates duplicated names and leaves unique names alone' do
      html = helper.assignment_select_options([ canvas_hw, gradescope_hw, project ], course, gradescope_hw.id)

      expect(html).to include(%(<option data-original-due-date="#{canvas_hw.due_date.strftime('%a, %b %-d, %Y at %-I:%M%P')}))
      expect(html).to include(%(value="#{canvas_hw.id}">Homework 1 [Canvas]</option>))
      expect(html).to include(%(selected="selected" value="#{gradescope_hw.id}">Homework 1 [Gradescope]</option>))
      expect(html).to include(%(value="#{project.id}">Project</option>))
      expect(html).not_to include('Project [')
    end

    it 'still disambiguates when only one of the duplicates is listed' do
      html = helper.assignment_select_options([ gradescope_hw, project ], course, nil)

      expect(html).to include('Homework 1 [Gradescope]')
    end
  end
end
