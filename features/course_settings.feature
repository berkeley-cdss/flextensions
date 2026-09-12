Feature: Course Settings

	Background:
		Given a course exists

	Scenario: Disabling a course shows flash message
		Given I'm logged in as a teacher
		When I go to the Course Details page
		And I uncheck "Enable Students to request extensions"
		And press "Save Course Details"
		Then I should see "Course details updated successfully."
		And I navigate to Course page
		Then I should see "Flextensions is disabled for this course. To allow to students to see this course"


	Scenario: Disabling a course shows flash message for student
		Given I'm logged in as a teacher
		When I go to the Course Details page
		And I uncheck "Enable Students to request extensions"
		And press "Save Course Details"
		Then I log in as a student
		And I go to the Course page
		Then I should see "Extensions are not enabled for this course."
