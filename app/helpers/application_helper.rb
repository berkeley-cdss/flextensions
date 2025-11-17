module ApplicationHelper
  def assignment_link_for(assignment, course)
    url = assignment.external_url
    case assignment.course_to_lms.lms_id
    when Lms.CANVAS.id
      name = 'bCourses'
    when Lms.GRADESCOPE.id
      name = 'Gradescope'
    else
      nil
    end
    link_to url, target: '_blank', class: 'text-nowrap ms-2', rel: 'noopener' do
      safe_join([ name, content_tag(:i, '', class: 'fas fa-up-right-from-square') ], ' ')
    end
  end
end
