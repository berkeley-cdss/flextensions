module ApplicationHelper
  def google_oauth_enabled?
    ENV['GOOGLE_CLIENT_ID'].present? && ENV['GOOGLE_CLIENT_SECRET'].present?
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
