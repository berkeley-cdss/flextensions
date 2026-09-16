module RequestsHelper
  def text_label_for(request)
    "Request for #{request.user.try(:name) || 'N/A'} - #{request.assignment&.name || 'N/A'}"
  end

  # Label for an assignment in a select. When another enabled assignment in the
  # course shares this name, the LMS name is appended so the two can be told apart.
  def assignment_option_label(assignment, duplicate_names)
    return assignment.name unless duplicate_names.include?(assignment.name)

    "#{assignment.name} [#{assignment.course_to_lms.lms.lms_name}]"
  end

  # Builds the `options_for_select` entries for the assignment dropdowns,
  # carrying the original due dates as data attributes for the Stimulus
  # extension-form controller.
  def assignment_select_options(assignments, course, selected)
    duplicate_names = course.duplicate_assignment_names
    options = assignments.map do |assignment|
      [
        assignment_option_label(assignment, duplicate_names),
        assignment.id,
        {
          'data-original-due-date' => assignment.due_date.strftime('%a, %b %-d, %Y at %-I:%M%P'),
          'data-original-late-due-date' => assignment.late_due_date&.strftime('%a, %b %-d, %Y at %-I:%M%P')
        }
      ]
    end
    options_for_select(options, selected)
  end

  def status_export_string(request)
    case request.status
    when 'pending'
      'Pending'
    when 'approved'
      if request.auto_approved
        "Auto Approved on #{request.updated_at.strftime('%a, %b %-d at %-I:%M%P')} by Auto Approval System"
      else
        "Approved on #{request.updated_at.strftime('%a, %b %-d at %-I:%M%P')} by #{request.last_processed_by_user&.name || 'Unknown'}"
      end
    when 'denied'
      "Denied on #{request.updated_at.strftime('%a, %b %-d at %-I:%M%P')} by #{request.last_processed_by_user&.name || 'Unknown'}"
    else
      'Unknown'
    end
  end
end
