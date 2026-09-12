require 'rails_helper'

RSpec.describe FormSetting, type: :model do
  describe '#effective_reason_title' do
    [ nil, '', '   ' ].each do |title|
      it "uses the default for #{title.inspect}" do
        setting = described_class.new(reason_title: title)

        expect(setting.effective_reason_title).to eq('Reason for Extension')
      end
    end

    it 'keeps the override specific to its course' do
      course = create(:course)
      other_course = create(:course)
      course.form_setting.update!(reason_title: 'How will this extension help?')

      expect(course.form_setting.reload.effective_reason_title).to eq('How will this extension help?')
      expect(other_course.form_setting.reload.effective_reason_title).to eq('Reason for Extension')
    end
  end
end
