FactoryBot.define do
  factory :user_to_course do
    association :user
    association :course
    role { 'student' }

    trait :as_teacher do
      role { 'teacher' }
    end

    trait :as_leadta do
      role { 'leadta' }
    end

    trait :as_ta do
      role { 'ta' }
    end

    trait :as_student do
      role { 'student' }
    end
  end
end
