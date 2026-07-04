class CoursesController < ApplicationController
  before_action :authenticate_user
  before_action :set_course, only: %i[show edit update sync_assignments sync_enrollments enrollments delete]
  before_action :set_pending_request_count
  before_action :determine_user_role
  before_action :require_course_staff, only: %i[edit update]

  def index
    teacher_courses = Enrollment.includes(:course).where(user: @user, role: Enrollment.staff_roles)
    @teacher_courses_by_semester = group_by_semester(teacher_courses)

    # Only show courses to students if extensions are enabled at the course level
    student_courses = Enrollment.includes(course: :course_settings).where(user: @user, role: 'student')
    visible_student_courses = student_courses.select { |enrollment| enrollment.course.requests_enabled? }
    @student_courses_by_semester = group_by_semester(visible_student_courses)

    # Keep flat lists for conditional checks in the view
    @teacher_courses = teacher_courses
    @student_courses = visible_student_courses
  end

  def show
    return redirect_to courses_path, alert: 'Course not found.' unless @course
    return redirect_to courses_path, alert: 'No Canvas LMS data found for this course.' unless @course.has_canvas_linked?

    @course.regenerate_readonly_api_token_if_blank

    if @role == 'student'
      return redirect_to courses_path, alert: 'Extensions are not enabled for this course.' unless @course.requests_enabled?

      @assignments = @course.enabled_assignments
    else
      @assignments = @course.assignments
      @assignments_last_synced_at = assignments_last_synced_at
    end
    render_role_based_view
  end

  def new
    token = @user.lms_credentials.first.token
    @courses = Course.fetch_courses(token)
    flash[:alert] = 'No courses found.' if @courses.empty?

    @semesters = @courses.filter_map { |c| Course.semester_from_term(c['term'], c['created_at']) }.uniq.sort
    @selected_semester = params[:semester]

    # TODO: Add spec for when a course is created, but the user is not enrolled in it.
    # TODO: Why do some courses have empty enrollments?
    existing_canvas_ids = @user.courses.pluck(:canvas_id)
    @courses_teacher = filter_courses(@courses, Enrollment.staff_roles, existing_canvas_ids)
    # Track if any teacher courses, so we still show the semester filter even if the selected semester filters out all courses.
    @has_any_teacher_courses = @courses_teacher.any?
    @courses_student = filter_courses(@courses, [ Enrollment::STUDENT_ROLE ], existing_canvas_ids)

    if @selected_semester.present?
      @courses_teacher = filter_by_semester(@courses_teacher, @selected_semester)
      @courses_student = filter_by_semester(@courses_student, @selected_semester)
    end
  end

  def edit
    @course_settings = @course.course_settings || @course.build_course_settings
  end

  def create
    token = @user.lms_credentials.first.token
    filter_courses(Course.fetch_courses(token), Enrollment.staff_roles)
      .select { |c| params[:courses]&.include?(c['id'].to_s) }
      .each { |course_api| Course.create_or_update_from_canvas(course_api, token, @user) }
    redirect_to courses_path, notice: 'Selected courses and their assignments have been imported successfully.'
  end

  def update
    @course_settings = @course.course_settings || @course.build_course_settings

    attrs = course_params.to_h
    # Only overwrite the semester when both dropdowns are set; this preserves a
    # value stored in an unexpected format that the picker left blank.
    semester = combined_semester
    attrs[:semester] = semester if semester.present?

    if @course.update(attrs) && @course_settings.update(course_settings_params)
      after_course_details_saved
    else
      errors = (@course.errors.full_messages + @course_settings.errors.full_messages).to_sentence
      flash.now[:alert] = "Failed to update course details: #{errors}"
      render :edit, status: :unprocessable_content
    end
  end

  def sync_assignments
    return render json: { error: 'Course not found.' }, status: :not_found unless @course

    @course.sync_assignments(@user)
    render json: { message: 'Assignments synced successfully.' }, status: :ok
  end

  def sync_enrollments
    return render json: { error: 'Course not found.' }, status: :not_found unless @course
    return render json: { error: 'You do not have permission.' }, status: :forbidden unless @course.course_staff?(@user)

    @course.sync_all_enrollments_from_canvas(@user.id)
    render json: { message: 'Users synced successfully.' }, status: :ok
  end

  def enrollments
    return redirect_to courses_path, alert: 'You do not have access to this page.' unless @role == 'instructor'

    @enrollments = @course.enrollments.includes(:user)
    @is_course_admin = @course.course_admin?(@user)
    @enrollments_last_synced_at = enrollments_last_synced_at
  end

  def delete
    return redirect_to courses_path, alert: 'You do not have access to this page.' unless @role == 'instructor'
    return redirect_to courses_path, alert: 'Extensions are enabled for this course.' if @course.requests_enabled?

    assignments = @course.assignments
    Extension.where(assignment_id: assignments.select(:id)).destroy_all
    assignments.destroy_all
    CourseToLms.where(course_id: @course.id).destroy_all
    Enrollment.where(course_id: @course.id).destroy_all
    Request.where(course_id: @course.id).destroy_all
    CourseSettings.where(course_id: @course.id).destroy_all
    FormSetting.where(course_id: @course.id).destroy_all
    Course.where.missing(:enrollments).destroy_all

    redirect_to courses_path, notice: 'Course deleted successfully.'
  end

  private

  def require_course_staff
    return if @course.course_staff?(@user)

    redirect_to course_path(@course.id), alert: 'You do not have access to this page.'
  end

  def course_params
    params.require(:course).permit(:course_name, :course_code, :demo_course)
  end

  # Course-level settings edited alongside the course itself on Course Details.
  def course_settings_params
    params.fetch(:course_settings, {}).permit(
      :enable_extensions,
      :enable_gradescope,
      :gradescope_course_url,
      :enable_emails,
      :reply_email,
      :enable_slack_webhook_url,
      :slack_webhook_url
    )
  end

  # Redirects after a successful save, sending a Slack ping when the webhook
  # was just enabled.
  def after_course_details_saved
    unless @course_settings.slack_webhook_just_enabled?
      return redirect_to edit_course_path(@course), notice: 'Course details updated successfully.'
    end

    if SlackNotifier.notify(@course_settings.slack_enabled_message, @course_settings.slack_webhook_url)
      redirect_to edit_course_path(@course), notice: 'Course details updated successfully. Check your Slack channel for notifications.'
    else
      redirect_to edit_course_path(@course), alert: 'Failed to send Slack notification. Please check the webhook URL.'
    end
  end

  # Combines the season + year dropdowns into a "Season Year" string, or nil
  # when either is blank.
  def combined_semester
    season = params.dig(:course, :semester_season)
    year = params.dig(:course, :semester_year)
    return nil if season.blank? || year.blank?

    "#{season} #{year}"
  end

  # Returns the time the roster was last synced from Canvas, or nil if never synced.
  def enrollments_last_synced_at
    synced_at = @course.course_to_lms&.recent_roster_sync&.dig('synced_at')
    return nil if synced_at.blank?

    Time.zone.parse(synced_at.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  # Returns the time assignments were last synced from the LMS, or nil if never synced.
  def assignments_last_synced_at
    synced_at = @course.course_to_lms&.recent_assignment_sync&.dig('synced_at')
    return nil if synced_at.blank?

    Time.zone.parse(synced_at.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def set_course
    @course = Course.find_by(id: params[:id])
    redirect_to courses_path, alert: 'Course not found.' unless @course
  end

  def determine_user_role
    @role = @course&.user_role(@user)
    @is_course_admin = @course&.course_admin?(@user) || false
  end

  # Groups Enrollment records by their course's semester, sorted most-recent-first.
  # Returns an array of [semester_name, [enrollments]] pairs.
  def group_by_semester(enrollments)
    grouped = enrollments.group_by { |enrollment| enrollment.course.semester }
    sorted_semesters = Course.sort_semesters(grouped.keys)
    sorted_semesters.map { |semester| [ semester, grouped[semester] ] }
  end

  # Filters Canvas API course hashes by their derived semester string
  def filter_by_semester(courses, semester)
    courses.select { |c| Course.semester_from_term(c['term'], c['created_at']) == semester }
  end

  # TODO: This should be moved to the Canvas Facade
  # TODO: Canvas enrollments can have multiple roles,
  # we SHOULD only look at the first one that matches our known roles.
  def filter_courses(courses, roles, exclude_ids = [])
    missing_enrollments = courses.select { |course| course['enrollments'].blank? }
    Rails.logger.warn("Canvas API by #{current_user.id}: Courses with missing enrollments: #{missing_enrollments.pluck('id').join(', ')}") unless missing_enrollments.empty?

    courses = courses - missing_enrollments - courses.select { |course| exclude_ids.include?(course['id'].to_s) }
    return [] if courses.empty?

    courses.select do |course|
      course['enrollments'].any? { |enrollment| roles.include?(Enrollment.role_from_canvas_enrollment(enrollment)) }
    end
  end

  def course_data_for_sync
    { 'id' => @course.canvas_id, 'name' => @course.course_name, 'course_code' => @course.course_code }
  end
end
