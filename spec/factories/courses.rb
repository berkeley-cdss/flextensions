# == Schema Information
#
# Table name: courses
#
#  id                 :bigint           not null, primary key
#  course_code        :string
#  course_name        :string
#  demo_course        :boolean          default(FALSE), not null
#  readonly_api_token :string
#  semester           :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_courses_on_readonly_api_token  (readonly_api_token) UNIQUE
#
FactoryBot.define do
  factory :course do
    sequence(:course_name) { |n| "Course #{n}" }
    sequence(:course_code) { |n| "COURSE#{n}" }
    semester { 'Spring 2026' }

    # Not a column: it becomes external_course_id on the course's Canvas link,
    # which is where Course#canvas_id reads from.
    transient do
      sequence(:canvas_id, &:to_s)
    end

    after(:create) do |course, evaluator|
      lms = Lms.find_by(id: 1) || create(:lms, id: 1, lms_name: 'Canvas')

      # Course settings are created automatically with the course; factory
      # courses default to extensions enabled since most specs need them.
      course.course_settings.update!(enable_extensions: true)
      create(:form_setting, course: course)
      course_to_lms = create(
        :course_to_lms,
        course: course,
        lms: lms,
        external_course_id: evaluator.canvas_id
      )
      create_list(:assignment, 5, course_to_lms: course_to_lms)
    end

    trait :with_students do
      after(:create) do |course|
        create_list(:user, 3, courses: [ course ])
      end
    end

    trait :with_staff do
      after(:create) do |course|
        create(:user, :with_canvas_token, courses: [ course ], role: 'teacher')
        create_list(:user, 3, :with_canvas_token, courses: [ course ], role: 'ta')
      end
    end
  end
end
