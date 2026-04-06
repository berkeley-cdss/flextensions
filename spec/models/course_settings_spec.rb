require 'rails_helper'

RSpec.describe CourseSettings, type: :model do
  let(:course) { create(:course, canvas_id: 'canvas_123', course_name: 'Test Course', course_code: 'TEST101') }
  let(:course_settings) { course.course_settings }

  describe 'associations' do
    it 'belongs to course' do
      expect(course_settings.course).to eq(course)
    end
  end

  describe 'validations' do
    context 'when enable_gradescope is true' do
      it 'validates gradescope_course_url format' do
        course_settings.enable_gradescope = true
        course_settings.gradescope_course_url = 'https://www.gradescope.com/courses/123456'
        expect(course_settings).to be_valid
      end

      it 'rejects invalid gradescope_course_url' do
        course_settings.enable_gradescope = true
        course_settings.gradescope_course_url = 'https://example.com/invalid'
        expect(course_settings).not_to be_valid
        expect(course_settings.errors[:gradescope_course_url]).to include('must be a valid Gradescope course URL like https://gradescope.com/courses/123456')
      end

      it 'accepts gradescope.com without www' do
        course_settings.enable_gradescope = true
        course_settings.gradescope_course_url = 'https://gradescope.com/courses/789012'
        expect(course_settings).to be_valid
      end

      it 'accepts gradescope_course_url with trailing slash' do
        course_settings.enable_gradescope = true
        course_settings.gradescope_course_url = 'https://www.gradescope.com/courses/123456/'
        expect(course_settings).to be_valid
      end

      it 'rejects gradescope_course_url without course ID' do
        course_settings.enable_gradescope = true
        course_settings.gradescope_course_url = 'https://www.gradescope.com/courses/'
        expect(course_settings).not_to be_valid
      end

      it 'rejects gradescope_course_url with non-numeric course ID' do
        course_settings.enable_gradescope = true
        course_settings.gradescope_course_url = 'https://www.gradescope.com/courses/abc'
        expect(course_settings).not_to be_valid
      end
    end

    context 'when enable_gradescope is false' do
      it 'does not validate gradescope_course_url' do
        course_settings.enable_gradescope = false
        course_settings.gradescope_course_url = 'invalid_url'
        expect(course_settings).to be_valid
      end
    end
  end

  describe '#create_or_update_gradescope_link' do
    context 'when enable_gradescope is true' do
      before do
        course_settings.enable_gradescope = true
        course_settings.gradescope_course_url = 'https://www.gradescope.com/courses/123456'
      end

      it 'creates a CourseToLms record for Gradescope' do
        expect do
          course_settings.save!
        end.to change(CourseToLms, :count).by(1)

        course_to_lms = CourseToLms.find_by(course_id: course.id, lms_id: GRADESCOPE_LMS_ID)
        expect(course_to_lms).to be_present
        expect(course_to_lms.external_course_id).to eq('123456')
      end

      it 'updates existing CourseToLms record if it already exists' do
        CourseToLms.create!(course_id: course.id, lms_id: GRADESCOPE_LMS_ID, external_course_id: '999999')

        expect do
          course_settings.save!
        end.not_to change(CourseToLms, :count)

        course_to_lms = CourseToLms.find_by(course_id: course.id, lms_id: GRADESCOPE_LMS_ID)
        expect(course_to_lms.external_course_id).to eq('123456')
      end

      it 'extracts course ID from URL without www' do
        course_settings.gradescope_course_url = 'https://gradescope.com/courses/789012'
        course_settings.save!

        course_to_lms = CourseToLms.find_by(course_id: course.id, lms_id: GRADESCOPE_LMS_ID)
        expect(course_to_lms.external_course_id).to eq('789012')
      end

      it 'extracts course ID from URL with trailing slash' do
        course_settings.gradescope_course_url = 'https://www.gradescope.com/courses/456789/'
        course_settings.save!

        course_to_lms = CourseToLms.find_by(course_id: course.id, lms_id: GRADESCOPE_LMS_ID)
        expect(course_to_lms.external_course_id).to eq('456789')
      end
    end

    context 'when enable_gradescope is false' do
      before do
        course_settings.enable_gradescope = false
      end

      it 'does not create a CourseToLms record' do
        expect do
          course_settings.save!
        end.not_to change(CourseToLms, :count)
      end
    end

    context 'when toggling enable_gradescope from true to false' do
      it 'does not delete existing CourseToLms record' do
        course_settings.enable_gradescope = true
        course_settings.gradescope_course_url = 'https://www.gradescope.com/courses/123456'
        course_settings.save!

        expect(CourseToLms.find_by(course_id: course.id, lms_id: GRADESCOPE_LMS_ID)).to be_present

        course_settings.enable_gradescope = false
        course_settings.save!

        # CourseToLms should still exist (TODO: this might be expected behavior to clean up)
        expect(CourseToLms.find_by(course_id: course.id, lms_id: GRADESCOPE_LMS_ID)).to be_present
      end
    end

    context 'when updating gradescope_course_url while enabled' do
      it 'updates the external_course_id' do
        course_settings.enable_gradescope = true
        course_settings.gradescope_course_url = 'https://www.gradescope.com/courses/123456'
        course_settings.save!

        course_settings.gradescope_course_url = 'https://www.gradescope.com/courses/999999'
        course_settings.save!

        course_to_lms = CourseToLms.find_by(course_id: course.id, lms_id: GRADESCOPE_LMS_ID)
        expect(course_to_lms.external_course_id).to eq('999999')
      end
    end
  end

  describe 'pending notification validations' do
    context 'pending_notification_frequency' do
      it 'accepts nil' do
        course_settings.pending_notification_frequency = nil
        expect(course_settings).to be_valid
      end

      it 'accepts "daily"' do
        course_settings.pending_notification_frequency = 'daily'
        course_settings.pending_notification_email = 'test@example.com'
        expect(course_settings).to be_valid
      end

      it 'accepts "weekly"' do
        course_settings.pending_notification_frequency = 'weekly'
        course_settings.pending_notification_email = 'test@example.com'
        expect(course_settings).to be_valid
      end

      it 'rejects "monthly"' do
        course_settings.pending_notification_frequency = 'monthly'
        course_settings.pending_notification_email = 'test@example.com'
        expect(course_settings).not_to be_valid
        expect(course_settings.errors[:pending_notification_frequency]).to be_present
      end
    end

    context 'pending_notification_email' do
      it 'is required when frequency is set' do
        course_settings.pending_notification_frequency = 'daily'
        course_settings.pending_notification_email = nil
        expect(course_settings).not_to be_valid
        expect(course_settings.errors[:pending_notification_email]).to be_present
      end

      it 'validates email format when frequency is set' do
        course_settings.pending_notification_frequency = 'daily'
        course_settings.pending_notification_email = 'not-an-email'
        expect(course_settings).not_to be_valid
        expect(course_settings.errors[:pending_notification_email]).to be_present
      end

      it 'accepts a valid email when frequency is set' do
        course_settings.pending_notification_frequency = 'daily'
        course_settings.pending_notification_email = 'instructor@berkeley.edu'
        expect(course_settings).to be_valid
      end

      it 'is not required when frequency is nil' do
        course_settings.pending_notification_frequency = nil
        course_settings.pending_notification_email = nil
        expect(course_settings).to be_valid
      end
    end

    context 'normalization' do
      it 'normalizes empty string frequency to nil' do
        course_settings.pending_notification_frequency = ''
        course_settings.valid?
        expect(course_settings.pending_notification_frequency).to be_nil
      end

      it 'normalizes empty string email to nil' do
        course_settings.pending_notification_email = ''
        course_settings.valid?
        expect(course_settings.pending_notification_email).to be_nil
      end

      it 'clears email when frequency is set to nil on save' do
        course_settings.pending_notification_frequency = 'daily'
        course_settings.pending_notification_email = 'test@example.com'
        course_settings.save!

        course_settings.pending_notification_frequency = nil
        course_settings.save!
        course_settings.reload

        expect(course_settings.pending_notification_email).to be_nil
      end
    end
  end

  describe '.with_pending_notifications' do
    it 'returns records matching the given frequency with an email set' do
      course_settings.update!(pending_notification_frequency: 'daily', pending_notification_email: 'a@example.com')

      other_course = create(:course, canvas_id: 'other_123', course_name: 'Other', course_code: 'OTHER101')
      other_course.course_settings.update!(pending_notification_frequency: 'weekly', pending_notification_email: 'b@example.com')

      results = CourseSettings.with_pending_notifications('daily')
      expect(results).to include(course_settings)
      expect(results).not_to include(other_course.course_settings)
    end

    it 'excludes records with nil email' do
      course_settings.update_columns(pending_notification_frequency: 'daily', pending_notification_email: nil)

      results = CourseSettings.with_pending_notifications('daily')
      expect(results).not_to include(course_settings)
    end
  end

  describe '#extract_gradescope_course_id' do
    it 'extracts course ID from valid URL' do
      url = 'https://www.gradescope.com/courses/123456'
      expect(course_settings.extract_gradescope_course_id(url)).to eq('123456')
    end

    it 'extracts course ID from URL without www' do
      url = 'https://gradescope.com/courses/789012'
      expect(course_settings.extract_gradescope_course_id(url)).to eq('789012')
    end

    it 'extracts course ID from URL with trailing slash' do
      url = 'https://www.gradescope.com/courses/456789/'
      expect(course_settings.extract_gradescope_course_id(url)).to eq('456789')
    end
  end
end
