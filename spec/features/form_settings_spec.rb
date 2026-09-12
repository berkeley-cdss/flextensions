require 'rails_helper'
require 'rack_session_access/capybara'

RSpec.describe 'Initial survey question', type: :feature do
  let(:teacher) { create(:user) }
  let(:student) { create(:user) }
  let(:course) { create(:course) }
  let(:custom_title) { 'What would more time help you accomplish?' }
  let(:extension_request) do
    create(:request, course: course, user: student, assignment: course.assignments.first)
  end

  around { |example| Capybara.using_driver(:rack_test) { example.run } }

  before do
    create(:enrollment, user: teacher, course: course, role: 'teacher')
    create(:enrollment, user: student, course: course, role: 'student')
    course.assignments.first.update!(enabled: true, due_date: 2.days.from_now)
    page.set_rack_session(user_id: teacher.canvas_uid)
  end

  it 'saves a course title and uses it on student and staff request pages' do
    visit edit_course_form_setting_path(course)
    fill_in 'form_setting_reason_title', with: custom_title
    click_button 'Save Form Settings'

    expect(page).to have_field('form_setting_reason_title', with: custom_title)

    visit new_course_request_path(course)
    expect(page).to have_selector('label[for="reason"]', text: custom_title, visible: :all)
    expect(page).to have_selector('textarea#reason[required]')

    page.set_rack_session(user_id: student.canvas_uid)
    visit new_course_request_path(course)
    expect(page).to have_selector('label[for="reason"]', text: custom_title, visible: :all)
    expect(page).to have_selector('textarea#reason[required]')

    visit edit_course_request_path(course, extension_request)
    expect(page).to have_field(custom_title, with: extension_request.reason)

    visit course_request_path(course, extension_request)
    expect(page).to have_selector('h3', text: custom_title)

    page.set_rack_session(user_id: teacher.canvas_uid)
    visit course_request_path(course, extension_request)
    expect(page).to have_selector('h3', text: custom_title)
  end

  it 'restores the default when the course title is cleared' do
    course.form_setting.update!(reason_title: custom_title)

    visit edit_course_form_setting_path(course)
    fill_in 'form_setting_reason_title', with: ''
    click_button 'Save Form Settings'

    visit new_course_request_path(course)
    expect(page).to have_selector('label[for="reason"]', text: 'Reason for Extension', visible: :all)
    expect(page).not_to have_text(custom_title)
  end
end
