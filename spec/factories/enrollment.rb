FactoryBot.define do
  factory :enrollment do
    association :user
    association :course
    role { 'student' }

    trait :as_teacher do
      role { 'teacher' }
    end

    trait :as_student do
      role { 'student' }
    end
  end
end
