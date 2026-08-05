module ApplicationHelper
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

  # Renders a small icon button that copies `text` to the clipboard.
  # `label` is used as both the tooltip and the accessible name, so pass
  # something specific when there are several buttons on a page.
  def copy_to_clipboard_button(text, label: 'Copy to clipboard', css_class: 'btn btn-sm btn-link p-0 ms-2')
    tag.button type: 'button',
               class: css_class,
               title: label,
               'aria-label': label,
               data: {
                 controller: 'clipboard',
                 action: 'click->clipboard#copy',
                 clipboard_text_value: text
               } do
      tag.i('', class: 'fas fa-clipboard', 'aria-hidden': true)
    end
  end

  # Small "last updated" note for the footer. Returns nil when we cannot work
  # out anything about the deployment, so the caller can omit the line entirely.
  def deployment_note
    parts = []
    parts << deployment_timestamp_tag if DeploymentInfo.deployed_at
    parts << deployment_commit_tag if DeploymentInfo.short_commit
    return nil if parts.empty?

    safe_join(parts, ' · ')
  end

  # `private def` rather than a `private` section: this module is mixed into
  # every view, so a sticky section would silently privatize helpers added below.
  private def deployment_timestamp_tag
    deployed_at = DeploymentInfo.deployed_at
    tag.time("Last updated #{deployed_at.strftime('%b %-d, %Y at %-l:%M %p %Z')}",
             datetime: deployed_at.iso8601,
             title: 'When this release was built')
  end

  private def deployment_commit_tag
    link_to DeploymentInfo.short_commit, DeploymentInfo.commit_url,
            target: '_blank', rel: 'noopener noreferrer',
            class: 'text-white text-decoration-underline', title: 'View this release on GitHub'
  end
end
