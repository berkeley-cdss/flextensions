class Lms < ApplicationRecord
  # Relationship with Course (and CourseToLms)
  has_many :course_to_lms
  has_many :courses, through: :course_to_lms

  # Relationship with Assignment
  has_many :assignments
end
