module ApplicationHelper
  # Identifies which sidebar entry is active for the current request, derived
  # from the controller and action rather than a per-action @side_nav ivar.
  def sidebar_section
    case "#{controller_name}##{action_name}"
    when 'courses#show'
      'show'
    when 'courses#edit', 'courses#update'
      'course_details'
    when 'courses#enrollments'
      'enrollments'
    when 'course_settings#approvals'
      'approvals'
    when 'course_settings#emails'
      'emails'
    when 'form_settings#edit', 'form_settings#update'
      'form_settings'
    when 'requests#new', 'requests#new_for_student'
      'form'
    when /\Arequests#/
      'requests'
    end
  end

  def assignment_link_for(assignment, course)
    case assignment.course_to_lms.lms_id
    when 1
      url = "#{ENV.fetch('CANVAS_URL')}/courses/#{course.canvas_id}/assignments/#{assignment.external_assignment_id}"
      name = 'bCourses'
    when 2
      url = "#{course.course_settings.gradescope_course_url}/assignments/#{assignment.external_assignment_id}"
      name = 'Gradescope'
    else
      nil
    end
    link_to url, target: '_blank', class: 'text-nowrap ms-2', rel: 'noopener' do
      safe_join([ name, content_tag(:i, '', class: 'fas fa-up-right-from-square') ], ' ')
    end
  end
end
