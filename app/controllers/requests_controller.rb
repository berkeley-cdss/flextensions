# We really should get a handle on this.
# rubocop:disable Metrics/ClassLength
class RequestsController < ApplicationController
  before_action :authenticate_user
  before_action :set_course
  before_action :require_course_staff!, only: %i[create_for_student approve reject mass_approve mass_reject]
  before_action :set_form_settings
  before_action :require_course_access
  before_action :set_request, only: %i[show edit update cancel approve reject]
  before_action :set_pending_request_count
  before_action :ensure_request_is_pending, only: %i[update approve reject]

  def index
    @side_nav = 'requests'
    if @course.staff_user?(current_user)
      scope = @course.requests.includes(:assignment)
      @requests = params[:show_all] == 'true' ? scope : scope.pending
    else
      @requests = @course.requests.for_user(current_user)
    end

    # Pass the search query to the view
    @search_query = params[:search]

    render_role_based_view
  end

  def show
    @assignment = @request.assignment
    @number_of_days = @request.calculate_days_difference if @request.requested_due_date.present? && @assignment&.due_date.present?
    render_role_based_view
  end

  def new
    @side_nav = 'form'
    if @course.staff_user?(current_user)
      prepare_instructor_new_request
      render :new_for_student
    else
      redirected = prepare_student_new_request
      render :new unless redirected
    end
  end

  def edit
    @selected_assignment = @request.assignment
    @assignments = [ @selected_assignment ]
  end

  def create
    Request.merge_date_and_time!(params[:request])
    @request = @course.requests.new(request_params.merge(user: current_user))
    return unless ensure_assignment_in_course

    if @request.assignment.has_pending_request_for_user?(current_user, @course)
      redirect_to course_requests_path(@course), alert: 'You already have a pending request for this assignment.'
      return
    end

    if @request.save
      result = @request.process_created_request(current_user)
      redirect_to result[:redirect_to], notice: result[:notice]
    else
      handle_request_error
    end
  end

  def create_for_student
    @side_nav = 'form'
    prepare_instructor_new_request
    student = User.find_by(id: params[:request][:user_id])

    unless @course.student_user?(student)
      return render :new_for_student, alert: 'The selected student is not enrolled in this course.'
    end

    Request.merge_date_and_time!(params[:request])
    @request.assign_attributes(request_params.merge(user: student))
    unless @course.enabled_assignments.exists?(id: @request.assignment_id)
      return render :new_for_student,
                    alert: 'The selected assignment is not enabled or in this course.'
    end

    # TODO: Move this logic or remove it. (Shouldn't instructors just edit or reject the existing request instead of creating a new one?)
    reject_other_student_requests(student, @request.assignment_id)

    if @request.save
      handle_successful_student_request(student)
    else
      render :new_for_student,
              alert: "There was a problem submitting the request. #{@request.errors.full_messages.join(', ')}"
    end
  end

  def update
    Request.merge_date_and_time!(params[:request])
    @request.assign_attributes(request_params)
    return unless ensure_assignment_in_course

    if @request.save
      result = @request.process_update(current_user)
      redirect_to result[:redirect_to], notice: result[:notice]
    else
      flash.now[:alert] = 'There was a problem updating the request.'
      render :edit
    end
  end

  def cancel
    if @request.reject(current_user)
      redirect_to course_requests_path(@course), notice: 'Request canceled successfully.'
    else
      redirect_to course_requests_path(@course), alert: 'Failed to cancel the request.'
    end
  end

  def approve
    if @request.approve_by(current_user)
      notice = 'Request approved and extension created successfully in Canvas.'
      respond_to do |format|
        format.html { redirect_to course_requests_path(@course), notice: notice }
        format.json { render json: { success: true, message: notice, new_status: 'approved', pending_count: @course.requests.pending.count } }
      end
    else
      alert = "Failed to approve the request. #{@request.errors.full_messages.join(', ')}"
      respond_to do |format|
        format.html { flash[:alert] = alert; redirect_to course_requests_path(@course) }
        format.json { render json: { success: false, message: alert }, status: :unprocessable_content }
      end
    end
  end

  def reject
    if @request.reject(current_user)
      notice = 'Request denied successfully.'
      respond_to do |format|
        format.html { redirect_to course_requests_path(@course), notice: notice }
        format.json { render json: { success: true, message: notice, new_status: 'denied', pending_count: @course.requests.pending.count } }
      end
    else
      alert = 'Failed to deny the request.'
      respond_to do |format|
        format.html { redirect_to course_requests_path(@course), alert: alert }
        format.json { render json: { success: false, message: alert }, status: :unprocessable_content }
      end
    end
  end

  def mass_approve
    process_mass_action(:approve)
  end

  def mass_reject
    process_mass_action(:reject)
  end

  private

  # Loads the request for member actions. Scoped so students can only reach
  # their own requests; anything outside the caller's scope is reported as
  # "not found" rather than leaking that it exists.
  def set_request
    @side_nav = 'requests'
    @request = requests_visible_to_user.includes(:assignment).find_by(id: params[:id])
    redirect_to course_path(@course), alert: 'Request not found.' unless @request
  end

  # Staff may act on any request in the course; everyone else is limited to
  # the requests they own.
  def requests_visible_to_user
    @course.staff_user?(@user) ? @course.requests : @course.requests.for_user(@user)
  end

  def handle_request_error
    flash.now[:alert] = "There was a problem submitting your request. #{@request.errors.full_messages.join(', ')}"
    @assignments = @course.enabled_assignments.order(:name)
    @selected_assignment = Assignment.find_by(id: params[:assignment_id]) if params[:assignment_id]
    render :new
  end

  def set_form_settings
    @form_settings = @course.form_setting
  end

  # The assignment is chosen at creation and is not editable afterwards, so the
  # update action is not permitted to write assignment_id; other actions may.
  def request_params
    permitted = [ :reason, :documentation, :custom_q1, :custom_q2, :requested_due_date ]
    permitted.unshift(:assignment_id) unless action_name == 'update'
    params.expect(request: permitted)
  end

  # Every request must reference an assignment in this course. A new request
  # that omits or points outside the course is an invalid submission and is
  # re-rendered with an error; an existing request keeps its (non-editable)
  # assignment, so a failure here means a tampered id and is treated as a 404.
  def ensure_assignment_in_course
    return true if @course.assignments.exists?(id: @request.assignment_id)

    @request.new_record? ? handle_request_error : head(:not_found)
    false
  end

  # Runs after set_request, so @request is already loaded and scoped; a missing
  # request has already been redirected as "not found" by set_request.
  def ensure_request_is_pending
    return if @request.pending?

    redirect_to course_path(@course),
                alert: 'This action can only be performed on pending requests.'
  end

  # Gate for every in-course request page. Three rules, in order:
  #   1. You must have a role in the course. Anyone else is turned away.
  #   2. Staff are always allowed through so they can manage requests.
  #   3. Students may only proceed when the course has extensions enabled.
  def require_course_access
    if @course.staff_user?(current_user)
      # rule 2: staff are always allowed.
    elsif @course.student_user?(current_user)
      # rule 3: students need extensions enabled.
      redirect_to courses_path, alert: 'Extensions are not enabled for this course.' unless @course.requests_enabled?
    else
      # rule 1: not enrolled in this course at all.
      redirect_to course_path(@course), alert: 'You do not have access to this page.'
    end
  end

  def prepare_instructor_new_request
    @students = User.joins(:enrollments).where(enrollments: { course_id: @course.id, role: 'student' }).order(:name)
    @request = @course.requests.new
    @assignments = @course.enabled_assignments.order(:name)
  end

  def prepare_student_new_request
    all_assignments = @course.enabled_assignments.order(:name)
    @assignments = all_assignments.reject { |assignment| assignment.has_pending_request_for_user?(current_user, @course) }
    @has_pending = all_assignments.size != @assignments.size
    @selected_assignment = Assignment.find_by(id: params[:assignment_id]) if params[:assignment_id]
    if @selected_assignment&.has_pending_request_for_user?(current_user, @course)
      pending_request = @course.requests.where(user: current_user, assignment: @selected_assignment, status: 'pending').first
      redirect_to course_request_path(@course, pending_request), alert: 'You already have a pending request for this assignment.' and return true
    end
    @request = @course.requests.new
    false
  end

  def reject_other_student_requests(student, assignment_id)
    @course.requests.where(user_id: student.id, assignment_id: assignment_id).where.not(status: 'denied').find_each do |req|
      req.update(status: 'denied', last_processed_by_user_id: current_user.id)
    end
  end

  def handle_successful_student_request(student)
    result = @request.process_created_request(current_user)
    redirect_to result[:redirect_to], notice: "Request created for #{student.name}. #{result[:notice]}"
  end

  def process_mass_action(action)
    request_ids = mass_request_ids
    if request_ids.empty?
      return render_mass_action_response(
        success: false,
        message: 'Please select at least one request.',
        processed_ids: [],
        failed_ids: [],
        new_status: action == :approve ? 'approved' : 'denied',
        status: :unprocessable_content
      )
    end

    requests = @course.requests.where(id: request_ids).pending.includes(:assignment)

    if requests.empty?
      return render_mass_action_response(
        success: false,
        message: 'No pending requests were found for the selected rows.',
        processed_ids: [],
        failed_ids: request_ids,
        new_status: action == :approve ? 'approved' : 'denied',
        status: :unprocessable_content
      )
    end

    processed_ids = []
    failed_ids = request_ids - requests.map(&:id)

    requests.each do |request|
      result = action == :approve ? approve_request_for_mass_action(request) : request.reject(current_user)
      result ? processed_ids << request.id : failed_ids << request.id
    end

    processed_count = processed_ids.size
    failed_count = failed_ids.size
    action_label = action == :approve ? 'approved' : 'denied'
    message =
      if failed_count.zero?
        "#{processed_count} request#{'s' unless processed_count == 1} #{action_label} successfully."
      else
        "#{processed_count} request#{'s' unless processed_count == 1} #{action_label}. "\
          "#{failed_count} failed."
      end

    render_mass_action_response(
      success: processed_count.positive?,
      message: message,
      processed_ids: processed_ids,
      failed_ids: failed_ids,
      new_status: action_label,
      status: processed_count.positive? ? :ok : :unprocessable_content
    )
  end

  def render_mass_action_response(success:, message:, processed_ids:, failed_ids:, new_status:, status:)
    pending_count = @course.requests.pending.count
    respond_to do |format|
      format.html do
        if success
          redirect_to course_requests_path(@course), notice: message
        else
          redirect_to course_requests_path(@course), alert: message
        end
      end
      format.json do
        render json: {
          success: success,
          message: message,
          processed_ids: processed_ids,
          failed_ids: failed_ids,
          new_status: new_status,
          pending_count: pending_count
        }, status: status
      end
    end
  end

  def approve_request_for_mass_action(request)
    request.approve_by(current_user)
  rescue StandardError => e
    Rails.logger.error("Mass approve failed for request #{request.id}: #{e.message}")
    Rails.error.report(e, handled: true,
                       context: { component: 'mass_approve', request_id: request.id, actor_id: @user&.id })
    false
  end

  def mass_request_ids
    Array(params[:request_ids]).map(&:to_i).uniq.select(&:positive?)
  end
end
# rubocop:enable Metrics/ClassLength
