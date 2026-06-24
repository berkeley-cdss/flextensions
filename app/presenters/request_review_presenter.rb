# Presents the extra context an instructor needs when reviewing an extension
# request before approving or denying it: the student's other requests in the
# same course (to spot patterns), summary counts, their enrollment, and the
# dates that would be applied on approval.
class RequestReviewPresenter
  def initialize(request)
    @request = request
    @course = request.course
  end

  # The student's other extension requests in this course, newest first.
  def student_requests
    @student_requests ||= @course.requests
                                 .where(user_id: @request.user_id)
                                 .where.not(id: @request.id)
                                 .includes(:assignment)
                                 .order(created_at: :desc)
  end

  def request_counts
    @request_counts ||= student_requests.group_by(&:status).transform_values(&:count)
  end

  def approved_count
    request_counts['approved'].to_i
  end

  def pending_count
    request_counts['pending'].to_i
  end

  def denied_count
    request_counts['denied'].to_i
  end

  def enrollment
    return @enrollment if defined?(@enrollment)

    @enrollment = UserToCourse.find_by(user_id: @request.user_id, course_id: @course.id)
  end

  def allow_extended_requests?
    enrollment&.allow_extended_requests || false
  end

  # The late due date that would be set on the assignment if this request is
  # approved, or nil when it cannot be calculated.
  def new_late_due_date
    return nil unless @request.requested_due_date.present? && @request.assignment&.due_date.present?

    @request.calculate_new_late_due_date
  end

  # Whether the request was submitted after the assignment's original due date.
  def submitted_after_deadline?
    due_date = @request.assignment&.due_date
    due_date.present? && @request.created_at > due_date
  end
end
