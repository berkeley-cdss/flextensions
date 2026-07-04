module ApplicationHelper
  # Identifies which sidebar entry is active for the current request, derived
  # from the controller and action rather than a per-action @side_nav ivar.
  def current_nav_page
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

  # Renders a sidebar link. Pass the nav key it represents and it highlights
  # itself when that is the current page. The label can be given as `text:` or,
  # for richer content like the requests badge, as a block.
  def sidebar_nav_item(path:, icon:, nav:, text: nil, &block)
    active = current_nav_page == nav
    label = block ? capture(&block) : text

    tag.li class: 'nav-item p-2' do
      link_to path, class: "nav-link d-flex align-items-center #{active ? 'active' : 'link-body-emphasis'}" do
        safe_join([
          tag.div(tag.i('', class: "#{icon} fa-fw me-3"), class: 'sidebar-icon-container ms-3'),
          tag.span(label, class: 'nav-text ms-2')
        ])
      end
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

  def display_role(user, course)
    enrollment = user.enrollments.find_by(course: course)
    enrollment ? enrollment.display_role : 'Unknown'
  end
end
