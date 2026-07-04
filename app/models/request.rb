# == Schema Information
#
# Table name: requests
#
#  id                        :bigint           not null, primary key
#  auto_approved             :boolean          default(FALSE), not null
#  custom_q1                 :text
#  custom_q2                 :text
#  documentation             :text
#  reason                    :text
#  requested_due_date        :datetime
#  status                    :enum             default("pending"), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  assignment_id             :bigint           not null
#  course_id                 :bigint           not null
#  external_extension_id     :string
#  last_processed_by_user_id :bigint
#  user_id                   :bigint           not null
#
# Indexes
#
#  index_requests_on_assignment_id              (assignment_id)
#  index_requests_on_auto_approved              (auto_approved)
#  index_requests_on_course_id                  (course_id)
#  index_requests_on_last_processed_by_user_id  (last_processed_by_user_id)
#  index_requests_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (assignment_id => assignments.id)
#  fk_rails_...  (course_id => courses.id)
#  fk_rails_...  (last_processed_by_user_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
class Request < ApplicationRecord
  belongs_to :course
  belongs_to :assignment
  belongs_to :user
  belongs_to :last_processed_by_user, class_name: 'User', optional: true

  delegate :form_setting, to: :course, allow_nil: true
  validates :requested_due_date, :reason, presence: true

  scope :pending, -> { where(status: 'pending') }
  scope :for_user, ->(user) { where(user: user).includes(:assignment) }
  scope :approved_for_user_in_course, lambda { |user, course|
    where(user: user, course: course, status: 'approved')
  }
  scope :auto_approved_for_user_in_course, lambda { |user, course|
    where(user: user, course: course, status: 'approved', auto_approved: true)
  }

  def pending?
    status == 'pending'
  end

  # Provisions the extension for this request through the assignment's LMS,
  # acting on behalf of acting_user. Returns false when the assignment has no
  # LMS facade. Shared by the single approve action and mass-approval so the
  # facade lookup lives on the model rather than in the controller.
  def approve_by(acting_user)
    facade = assignment&.lms_facade
    return false unless facade

    approve(facade.from_user(acting_user), acting_user)
  end

  # Class methods
  def self.merge_date_and_time!(request_params)
    return unless request_params[:requested_due_date].present? && request_params[:due_time].present?

    combined = Time.zone.parse("#{request_params[:requested_due_date]} #{request_params[:due_time]}")
    request_params[:requested_due_date] = combined
  end

  # Process a newly created request, including auto-approval check
  def process_created_request(current_user)
    link = request_link

    if try_auto_approval(current_user)
      slack_message, result = build_created_slack_and_result(:auto_approved, link)
    else
      slack_message, result = build_created_slack_and_result(:pending, link)
      slack_message += auto_approval_breakdown_slack_note if auto_approval_breakdown
    end

    notify_slack(slack_message)

    result
  end

  # Handle request update and check for auto-approval
  def process_update(_current_user)
    link = request_link
    notify_slack = true

    if status == 'pending' && try_auto_approval(_current_user)
      slack_message = build_slack_message(:auto_approved, link)
      result = build_result_hash('Your request was updated and has been approved.')
    else
      slack_message = build_slack_message(:updated, link)
      slack_message += auto_approval_breakdown_slack_note if auto_approval_breakdown
      result = build_result_hash('Request was successfully updated.')
    end

    success = SlackNotifier.notify(slack_message, course.course_settings.slack_webhook_url) if notify_slack && course.course_settings.slack_webhook_url.present?
    Rails.logger.error "Failed to send Slack notification for request #{id} in course #{course.id}. Please check your webhook URL." unless success
    result
  end

  def calculate_days_difference
    (requested_due_date.to_date - assignment.due_date.to_date).to_i
  end

  # Set when a request met the auto-approval rules but could not be approved
  # because no staff member's Canvas access worked; used to warn course staff.
  attr_reader :auto_approval_breakdown

  # Attempt to auto-approve by posting to the LMS. Credentials on file can be
  # stale (Canvas revokes refresh tokens that go unused for months) and a
  # staff member may have left the Canvas course, so when one staff user's
  # token cannot be refreshed or the LMS rejects the approval, fall back to
  # the next staff user rather than giving up.
  def try_auto_approval(_current_user)
    return false unless auto_approval_eligible_for_course?
    return false unless eligible_for_auto_approval?

    candidates = course.staff_users_for_auto_approval
    if candidates.empty?
      flag_auto_approval_breakdown('no staff member has connected a Canvas account')
      return false
    end

    candidates.each do |approval_user|
      if approval_user.ensure_fresh_canvas_token!.blank?
        Rails.logger.warn "Auto-approval for request #{id}: could not refresh the Canvas token for staff user #{approval_user.id}; trying the next staff user."
        next
      end

      return true if auto_approve(assignment.lms_facade.from_user(approval_user))

      Rails.logger.warn "Auto-approval for request #{id}: the LMS rejected the approval as staff user #{approval_user.id}; trying the next staff user."
    end

    flag_auto_approval_breakdown("no staff member's Canvas access is currently working")
    false
  end

  def auto_approval_eligible_for_course?
    course.course_settings.automatic_approval_enabled?
  end

  def eligible_for_auto_approval?
    return false unless auto_approval_eligible_for_course?
    return false unless meets_min_hours_before_deadline?

    enrollment = UserToCourse.find_by(user: user, course: course)
    return false if enrollment.nil?
    if enrollment.allow_extended_requests
      # Extended-request students get at least the standard window; a course
      # that leaves auto_approve_extended_request_days at 0 must not exclude
      # them from the auto-approval every other student gets.
      max_days = [ course.course_settings.auto_approve_extended_request_days,
                   course.course_settings.auto_approve_days ].max
    else
      max_days = course.course_settings.auto_approve_days
    end

    days_difference = calculate_days_difference
    return false if days_difference <= 0 || (days_difference > max_days)

    max_approvals = course.course_settings.max_auto_approve
    return true if max_approvals.zero? # If max is 0, there's no limit

    auto_approved_count = Request.auto_approved_for_user_in_course(user, course).count
    auto_approved_count < max_approvals
  end

  # When enabled, a request is only eligible for auto-approval if it is made at
  # least the configured number of hours before the assignment's deadline. With
  # a value of 0 (the default), this simply requires the deadline to not yet
  # have passed.
  def meets_min_hours_before_deadline?
    settings = course.course_settings
    return true unless settings.enable_min_hours_before_deadline

    hours_until_deadline = (assignment.due_date - Time.current) / 1.hour
    met = hours_until_deadline >= settings.min_hours_before_deadline.to_i
    unless met
      Rails.logger.info "Auto-approval skipped for request #{id}: #{hours_until_deadline.round(1)}h until deadline " \
                        "is under the #{settings.min_hours_before_deadline.to_i}h minimum for course #{course.id}."
    end
    met
  end

  def auto_approve(lms_facade_from_user)
    return false unless eligible_for_auto_approval?

    system_user = SystemUserService.ensure_auto_approval_user_exists
    return false unless system_user

    # Reuse the regular approve method but mark as auto-approved afterward
    result = approve(lms_facade_from_user, system_user)
    update(auto_approved: true) if result
    result
  end

  # TODO: All of these code should really be moved to each LMS' facade class
  def approve(lms_facade, processed_user_id)
    begin
      case lms_facade
      when CanvasFacade
        course_id = course.canvas_id
        user_id = user.canvas_uid.to_i
      when GradescopeFacade
        course_id = course.gradescope_id
        user_id = user.email
      else
        raise "Unsupported LMS Facade: #{lms_facade.class.name}"
      end

      dates = date_calculator.calculate
      override = lms_facade.provision_extension(
        course_id,
        user_id,
        assignment.external_assignment_id,
        dates[:due_date].iso8601,
        dates[:late_due_date]&.iso8601
      )
    rescue => e
      Rails.logger.error "Error during LMS extension provisioning: #{e.message}"
      self.errors.add(:base, 'Failed to provision extension in LMS.')
      self.errors.add(:base, e.message)
      return false
    end

    update(
      status: 'approved',
      last_processed_by_user_id: processed_user_id.id,
      external_extension_id: override&.id)
    send_email_response if course.course_settings.enable_emails
    true
  end

  # Returns the AssignmentDateCalculator for this request
  def date_calculator
    @date_calculator ||= AssignmentDateCalculator.new(
      assignment: assignment,
      request: self,
      course_settings: course.course_settings
    )
  end

  # Calculates the new late due date for an extension based on course settings.
  # Returns nil if the assignment has no late due date.
  # Delegates to AssignmentDateCalculator for the actual calculation.
  def calculate_new_late_due_date
    date_calculator.late_due_date
  end

  def reject(processed_user_id)
    update(status: 'denied', last_processed_by_user_id: processed_user_id.id)
    # Only send email if the person processing is the same as the request's user
    send_email_response if course.course_settings.enable_emails && processed_user_id.id != user_id
    true
  end

  # Based on this request, set the right 3 assignment dates
  # Always keep the assignment release date the same
  # Calculate the delta from the original due date to the requested due date
  # Set the due date to the requested due date
  # If the current (approval) time is beyond the requested due date,
  #   then extend the requested due date by the delta with a max of 3 days
  # If the flag EXTEND_LATE_DUE_DATE is set, then set the late due date to
  #   the delta beyond the requested due date, otherwise keep it the same
  # If the flag EXTEND_LATE_DUE_DATE is not set, ensure that the late due date
  #   is at least as late as the requested due date
  def calculate_new_assignment_dates
    {
      release_date: assignment_release_date,
      due_date: requested_due_date,
      late_due_date: late_due_date,
      message: approval_message
    }
  end

  def send_email_response
    return unless course.course_settings.enable_emails

    cs = course.course_settings
    to = user.email
    reply_to = cs.reply_email.presence || ENV.fetch('DEFAULT_FROM_EMAIL')

    # build the mapping without braces:
    mapping = {
      'student_name' => user.name,
      'assignment_name' => assignment.name,
      'course_name' => course.course_name,
      'course_code' => course.course_code,
      'status' => status.capitalize,
      'original_due_date' => assignment.due_date.strftime('%a, %b %-d, %Y %-I:%M %p'),
      'new_due_date' => requested_due_date.strftime('%a, %b %-d, %Y %-I:%M %p'),
      'extension_days' => calculate_days_difference.to_s
    }

    EmailService.send_email(
      to: to,
      from: ENV.fetch('DEFAULT_FROM_EMAIL'),
      reply_to: reply_to,
      subject_template: cs.email_subject,
      body_template: cs.email_template,
      mapping: mapping,
      deliver_later: false # or true if you prefer .deliver_later
    )
  end

  def self.to_csv(requests)
    headers = [ 'Assignment', 'Student Name', 'Student ID', 'Requested At', 'Original Due Date', 'Requested Due Date', 'Status' ]
    CSV.generate(headers: true) do |csv|
      csv << headers
      requests.find_each do |request|
        csv << [
          request.assignment&.name,
          request.user&.name,
          request.user&.student_id,
          request.created_at,
          request.assignment&.due_date,
          request.requested_due_date,
          request.status
        ]
      end
    end
  end

  private

  def flag_auto_approval_breakdown(reason)
    @auto_approval_breakdown = reason
    Rails.logger.warn "Auto-approval broken for request #{id} in course #{course.id}: #{reason}. " \
                      'A staff member must log in to Flextensions to reconnect Canvas.'
  end

  def auto_approval_breakdown_slack_note
    "\n:warning: This request met the auto-approval rules, but #{auto_approval_breakdown}. " \
      'A staff member should log in to Flextensions to reconnect Canvas, then approve pending requests manually.'
  end

  def build_slack_message(type, link)
    case type
    when :auto_approved
      "A pending request was *updated and auto-approved* for '#{assignment&.name}' (#{user&.name}) in course '#{course&.course_name}'.\nView: #{link}"
    when :updated
      "A pending request was *updated* for '#{assignment&.name}' (#{user&.name}) in course '#{course&.course_name}'.\nView: #{link}"
    end
  end

  def build_result_hash(notice)
    {
      redirect_to: Rails.application.routes.url_helpers.course_request_path(course, id),
      notice: notice
    }
  end

  def build_created_slack_and_result(type, link)
    case type
    when :auto_approved
      [
        "A request was *auto-approved* for '#{assignment&.name}' (#{user&.name}) in course '#{course&.course_name}'.\nView: #{link}",
        {
          redirect_to: Rails.application.routes.url_helpers.course_request_path(course, id),
          notice: 'Your extension request has been approved.'
        }
      ]
    when :pending
      [
        "A new extension request is *pending* for review: '#{assignment&.name}' (#{user&.name}) in course '#{course&.course_name}'.\nView: #{link}",
        {
          redirect_to: Rails.application.routes.url_helpers.course_request_path(course, id),
          notice: 'Your extension request has been submitted.'
        }
      ]
    end
  end

  def notify_slack(slack_message)
    return if course.course_settings.slack_webhook_url.blank?

    success = SlackNotifier.notify(slack_message, course.course_settings.slack_webhook_url)
    Rails.logger.error "Failed to send Slack notification for request #{id} in course #{course.id}. Please check your webhook URL." unless success
  end

  def request_link
    base_host = ENV['APP_HOST'].presence || Rails.application.routes.default_url_options[:host].presence
    return Rails.application.routes.url_helpers.course_request_path(course, id) if base_host.blank?

    normalized_host = base_host.start_with?('http://', 'https://') ? base_host : "https://#{base_host}"
    "#{normalized_host.chomp('/')}/courses/#{course.id}/requests/#{id}"
  end
end
