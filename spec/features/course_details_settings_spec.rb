require 'rails_helper'
require 'rack_session_access/capybara'

# Course Details ("/courses/:id/edit") settings behavior. The server-rendered
# states run under rack_test; the toast / unsaved-changes behavior needs a real
# browser and is tagged :js, :a11y so it runs in the browser CI job.
RSpec.describe 'Course Details settings', type: :feature do
  let(:teacher) { create(:user, email: 'teacher@example.com', canvas_uid: 'teacher-uid', name: 'Teacher') }
  let(:course) { create(:course, course_name: 'Test Course', course_code: 'TST101') }

  before do
    create(:enrollment, user: teacher, course: course, role: 'teacher')
    teacher.lms_credentials.create!(lms_id: 1, token: 'tok', expire_time: 1.hour.from_now)
  end

  describe 'Enable Extensions and Delete Course (server-rendered)' do
    around { |example| Capybara.using_driver(:rack_test) { example.run } }

    before { page.set_rack_session(user_id: teacher.canvas_uid) }

    context 'when student requests are turned off' do
      before { course.course_settings.update!(enable_extensions: false) }

      it 'highlights the Enable Extensions section with the info border and an XL switch' do
        visit edit_course_path(course)

        expect(page).to have_selector('h2', text: 'Enable Extensions')
        expect(page).to have_selector('.card.border-info', text: 'Enable Extensions')
        expect(page).to have_selector('.form-switch.checkbox-xl #course-enable')
        expect(page).to have_text('Students cannot request extensions for this course until this is enabled.')
      end

      it 'offers an enabled Delete Course link' do
        visit edit_course_path(course)

        expect(page).to have_link('Delete Course', href: delete_course_path(course))
        expect(page).not_to have_button('Delete Course')
      end
    end

    context 'when student requests are turned on' do
      before { course.course_settings.update!(enable_extensions: true) }

      it 'drops the info border' do
        visit edit_course_path(course)

        expect(page).to have_selector('h2', text: 'Enable Extensions')
        expect(page).not_to have_selector('.card.border-info', text: 'Enable Extensions')
      end

      it 'disables Delete Course and explains why via a tooltip' do
        visit edit_course_path(course)

        expect(page).to have_button('Delete Course', disabled: true)
        expect(page).not_to have_link('Delete Course')
        tooltip = find('[data-controller="tooltip"]')
        expect(tooltip['title']).to eq('Disable student extension requests before deleting this course.')
      end
    end
  end

  describe 'notification settings placement' do
    around { |example| Capybara.using_driver(:rack_test) { example.run } }

    before { page.set_rack_session(user_id: teacher.canvas_uid) }

    it 'keeps Slack/pending notifications (with webhook instructions) under Staff Notifications on Course Details' do
      visit edit_course_path(course)

      expect(page).to have_selector('h2', text: 'Staff Notifications')
      expect(page).to have_link('Instructions on how to create a Slack Webhook',
                                href: 'https://berkeley-cdss.github.io/flextensions/integrations/#slack')
      expect(page).to have_text('All notifications will arrive in as an individual Slack message')
      # email fields have moved off this page
      expect(page).to have_no_field('course_settings[enable_emails]')
      expect(page).to have_no_field('course_settings[reply_email]')
    end

    it 'shows the email notification toggle and reply-to address on the Email Templates page' do
      visit emails_course_settings_path(course)

      expect(page).to have_field('course_settings[enable_emails]', visible: :all)
      expect(page).to have_field('course_settings[reply_email]', disabled: :all)
    end
  end

  describe 'unsaved changes warning', :a11y, :js do
    before do
      page.set_rack_session(user_id: teacher.canvas_uid)
      course.course_settings.update!(enable_extensions: true)
    end

    it 'shows a toast when a setting changes and clears it on save' do
      visit edit_course_path(course)

      expect(page).not_to have_selector('.toast.show')

      fill_in 'course-name', with: 'A New Course Name'

      expect(page).to have_selector('.toast.show',
                                    text: 'You have unsaved changes to your course. Please select save if you wish to keep your changes.')

      click_button 'Save Course Details'

      # Saving navigates without a beforeunload prompt blocking it (the hook was
      # cleared), and the toast is gone on the freshly rendered page.
      expect(page).to have_text('Course details updated successfully.')
      expect(page).not_to have_selector('.toast.show')
    end
  end
end
