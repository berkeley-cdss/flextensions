class CoursesController < ApplicationController
  before_action :set_course, only: %i[show edit sync_assignments sync_enrollments enrollments delete]
  # Currently exclude routes that expect JSON.
  before_action :require_course_staff!, only: %i[edit enrollments delete]
  before_action :set_pending_request_count

  def index
    staff_enrollments = Enrollment.includes(:course)
                                  .where(user: current_user, role: Enrollment.staff_roles)
                                  .keep_highest_role
    @staff_enrollments_by_semester = group_by_semester(staff_enrollments)

    # Only show courses to students if extensions are enabled at the course level
    student_courses = Enrollment.includes(course: :course_settings).where(user: current_user, role: 'student')
    visible_student_courses = student_courses.select { |enrollment| enrollment.course.requests_enabled? }
    @student_enrollments_by_semester = group_by_semester(visible_student_courses)
  end

  def show
    # TODO: This shouldn't be possible. Remove?
    return redirect_to courses_path, alert: 'No Canvas LMS data found for this course.' unless @course.has_canvas_linked?

    @side_nav = 'show'
    @course.regenerate_readonly_api_token_if_blank

    if @course.staff_user?(current_user)
      @assignments = @course.assignments
      @assignments_last_synced_at = assignments_last_synced_at
      render :instructor_show
    elsif @course.student_user?(current_user)
      return redirect_to courses_path, alert: 'Extensions are not enabled for this course.' unless @course.requests_enabled?
      @assignments = @course.enabled_assignments
      render :student_show
    else
      redirect_to courses_path, alert: 'You do not have access to this course.'
    end
  end

  def new
    token = current_user.lms_credentials.first.token
    @courses = Course.fetch_courses(token)
    flash[:alert] = 'No courses found.' if @courses.empty?

    @semesters = @courses.filter_map { |c| Course.semester_from_term(c['term'], c['created_at']) }.uniq.sort
    @selected_semester = params[:semester]

    # TODO: Add spec for when a course is created, but the user is not enrolled in it.
    # TODO: Why do some courses have empty enrollments?
    existing_canvas_ids = current_user.courses.pluck(:canvas_id)
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
    @side_nav = 'edit'
  end

  def create
    token = current_user.lms_credentials.first.token
    filter_courses(Course.fetch_courses(token), Enrollment.staff_roles)
      .select { |c| params[:courses]&.include?(c['id'].to_s) }
      .each { |course_api| Course.create_or_update_from_canvas(course_api, token, current_user) }
    redirect_to courses_path, notice: 'Selected courses and their assignments have been imported successfully.'
  end

  def sync_assignments
    return render json: { error: 'Course not found.' }, status: :not_found unless @course

    @course.sync_assignments(current_user)
    render json: { message: 'Assignments synced successfully.' }, status: :ok
  end

  def sync_enrollments
    return render json: { error: 'Course not found.' }, status: :not_found unless @course
    return render json: { error: 'You do not have permission.' }, status: :forbidden unless @course.staff_user?(current_user)

    @course.sync_all_enrollments_from_canvas(current_user.id)
    render json: { message: 'Users synced successfully.' }, status: :ok
  end

  def enrollments
    @side_nav = 'enrollments'
    @enrollments = @course.enrollments.includes(:user)
    @enrollments_last_synced_at = enrollments_last_synced_at
  end

  def delete
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
