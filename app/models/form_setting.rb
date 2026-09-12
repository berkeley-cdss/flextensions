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
#  index_form_settings_on_course_id  (course_id)
#
# Foreign Keys
#
#  fk_rails_...  (course_id => courses.id)
#
class FormSetting < ApplicationRecord
  # Shown as the heading of the always-required reason question when a course
  # has not supplied its own wording.
  DEFAULT_REASON_TITLE = 'Why do you need this extension?'.freeze

  belongs_to :course

  # model-level validations for display enums
  validates :documentation_disp, :custom_q1_disp, :custom_q2_disp, inclusion: { in: %w[required optional hidden] }

  # The reason question's heading as students and staff should see it: the
  # course override when one is set, otherwise the system default.
  def reason_title_or_default
    reason_title.presence || DEFAULT_REASON_TITLE
  end
end
