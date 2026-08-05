require 'rails_helper'

RSpec.describe NullUser do
  subject(:null_user) { described_class.new }

  it 'is a User, so anything expecting one can take it' do
    expect(null_user).to be_a(User)
  end

  it 'is not logged in' do
    expect(null_user).not_to be_logged_in
    expect(create(:user)).to be_logged_in
  end

  it 'is blank, so the `current_user.present?` idiom still means "logged in"' do
    expect(null_user).to be_blank
    expect(null_user).not_to be_present
  end

  it 'has no identity of its own' do
    expect(null_user.id).to be_nil
    expect(null_user.name).to eq('Guest')
    expect(null_user).not_to be_persisted
  end

  it 'is never an admin' do
    expect(null_user).not_to be_admin
  end

  describe 'associations' do
    it 'owns nothing' do
      expect(null_user.requests).to be_empty
      expect(null_user.processed_requests).to be_empty
      expect(null_user.lms_credentials).to be_empty
      expect(null_user.enrollments).to be_empty
      expect(null_user.courses).to be_empty
    end

    it 'returns relations, so callers can keep chaining' do
      course = create(:course)

      expect(null_user.enrollments.find_by(course: course)).to be_nil
      expect(null_user.lms_credentials.first).to be_nil
      expect(null_user.requests.where(status: 'pending')).to be_empty
    end

    it 'ignores records belonging to real users' do
      user = create(:user, :with_canvas_token)
      course = create(:course)
      create(:enrollment, user: user, course: course, role: 'teacher')

      expect(null_user.enrollments).to be_empty
      expect(null_user.courses).to be_empty
      expect(null_user.lms_credentials).to be_empty
    end
  end

  describe 'Canvas credentials' do
    it 'has none, and cannot produce a token' do
      expect(null_user.canvas_credentials).to be_nil
      expect(null_user.ensure_fresh_canvas_token!).to be_nil
    end
  end

  describe 'authorization' do
    let(:course) { create(:course) }

    it 'holds no role in any course' do
      expect(course.user_role(null_user)).to be_nil
      expect(course.enrolled?(null_user)).to be(false)
      expect(course.staff_user?(null_user)).to be(false)
      expect(course.student_user?(null_user)).to be(false)
      expect(course.course_admin?(null_user)).to be(false)
    end

    # enrollments.user_id is nullable, so a naive `where(user_id: user.id)`
    # lookup would match the rows left behind by a deleted user and hand their
    # role to a logged-out visitor.
    it 'does not inherit the role of an enrollment whose user was removed' do
      orphan = create(:enrollment, course: course, role: 'teacher')
      orphan.update_column(:user_id, nil) # rubocop:disable Rails/SkipsModelValidations

      expect(course.staff_user?(null_user)).to be(false)
      expect(course.enrolled?(null_user)).to be(false)
      expect(course.user_role(null_user)).to be_nil
    end
  end

  describe 'query interoperability' do
    it 'matches no records when handed to a scope expecting a user' do
      course = create(:course)
      create(:request, course: course, assignment: course.assignments.first, user: create(:user))

      expect(Request.for_user(null_user)).to be_empty
      expect(Request.where(user: null_user)).to be_empty
    end
  end

  # `readonly?` is what actually stops a write; the email validation happens to
  # reject a bare NullUser first, so bypass it to prove the guard is there.
  it 'refuses to be saved' do
    expect(null_user).to be_readonly
    expect { null_user.save!(validate: false) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { null_user.save! }.to raise_error(ActiveRecord::ActiveRecordError)
    expect(null_user).not_to be_persisted
  end
end
