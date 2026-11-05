FactoryBot.define do
  factory :request do
    association :course
    association :user
    association :assignment
    reason { 'Extension request reason' }
    status { 'pending' }
    # Relative to the assignment, whose due date can be any number of days away.
    requested_due_date { (assignment&.due_date || Time.current) + 14.days }

    trait :approved do
      status { 'approved' }
    end

    trait :denied do
      status { 'denied' }
    end
  end
end
