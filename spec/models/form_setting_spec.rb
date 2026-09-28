require 'rails_helper'

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
