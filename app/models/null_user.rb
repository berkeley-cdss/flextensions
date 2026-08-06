# The logged-out user.
#
# `current_user` never returns nil -- callers always get a User instance, so
# they can call `current_user.name`, `current_user.admin?` or
# `course.staff_user?(current_user)` without a nil check first. When nobody is
# logged in, that instance is a NullUser: a real (never-persisted) User that
# owns nothing, belongs to no course, and is authorized for nothing.
#
# Two deliberate choices make this safe to hand to existing code:
#
#   * It is a `User` subclass, not a stand-in object, so ActiveRecord accepts
#     it wherever a user is expected (`Request.where(user: current_user)`
#     narrows to `user_id IS NULL`, which matches nothing).
#   * It is `blank?`, so the `current_user.present?` idiom keeps meaning "is
#     somebody logged in?" rather than silently becoming true everywhere.
#
# Ask `logged_in?` when you specifically need to branch on being signed in.
# == Schema Information
#
# Table name: users
#
#  id         :bigint           not null, primary key
#  admin      :boolean          default(FALSE)
#  canvas_uid :string
#  email      :string
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  student_id :string
#
# Indexes
#
#  index_users_on_canvas_uid  (canvas_uid) UNIQUE
#  index_users_on_email       (email) UNIQUE
#
class NullUser < User
  NAME = 'Guest'.freeze

  def id = nil
  def name = NAME
  def admin? = false

  def logged_in? = false

  # Rails treats a NullUser the way it treats nil: `present?` is false, so
  # `if current_user.present?` still means "somebody is logged in".
  # ActiveRecord::Core hardcodes both of these (a record is never blank), so
  # overriding `blank?` alone would leave `present?` returning true.
  def blank? = true
  def present? = false

  # A NullUser stands for the absence of a user, so it must never reach the
  # database. ActiveRecord checks this on both create and update and raises
  # ActiveRecord::ReadOnlyRecord.
  def readonly? = true

  # Every association is empty. These return real (empty) relations rather than
  # arrays so callers can keep chaining -- `.find_by`, `.where`, `.empty?` and
  # `.first` all behave as they would for a user with no records.
  def requests = Request.none
  def processed_requests = Request.none
  def lms_credentials = LmsCredential.none
  def enrollments = Enrollment.none
  def courses = Course.none
end
