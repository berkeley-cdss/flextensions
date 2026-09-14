require 'rails_helper'

# == Schema Information
#
# Table name: form_settings
#
#  id                 :bigint           not null, primary key
#  custom_q1          :string
#  custom_q1_desc     :text
#  custom_q1_disp     :enum
#  custom_q2          :string
#  custom_q2_desc     :text
#  custom_q2_disp     :enum
#  documentation_desc :text
#  documentation_disp :enum
#  reason_desc        :text
#  reason_title       :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  course_id          :bigint           not null
#
# Indexes
#
#  index_form_settings_on_course_id  (course_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (course_id => courses.id)
#
RSpec.describe FormSetting, type: :model do
  let(:course) { create(:course) }
  let(:form_setting) { course.form_setting }

  describe '#reason_title_or_default' do
    it 'falls back to the default title when no override is set' do
      form_setting.update!(reason_title: nil)
      expect(form_setting.reason_title_or_default).to eq(FormSetting::DEFAULT_REASON_TITLE)
    end

    it 'treats a blank override as unset' do
      form_setting.update!(reason_title: '   ')
      expect(form_setting.reason_title_or_default).to eq('Why do you need this extension?')
    end

    it 'returns the course override when one is set' do
      form_setting.update!(reason_title: 'Why do you need more time?')
      expect(form_setting.reason_title_or_default).to eq('Why do you need more time?')
    end
  end
end
