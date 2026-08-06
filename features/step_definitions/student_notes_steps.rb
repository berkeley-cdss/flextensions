# Navigate to the request show page for a given assignment
When(/^I view the request for "([^"]*)"$/) do |assignment_name|
  request = Request.joins(:assignment).find_by(assignments: { name: assignment_name })
  raise "No request found for assignment #{assignment_name}" unless request

  visit course_request_path(@course, request)
end

# Set notes on the student's enrollment in the course
Given(/^the student for the course has notes "([^"]*)"$/) do |notes_text|
  student = User.joins(:enrollments).find_by(enrollments: { course: @course, role: 'student' })
  enrollment = Enrollment.find_by(user: student, course: @course, role: 'student')
  enrollment.update!(notes: notes_text)
end
