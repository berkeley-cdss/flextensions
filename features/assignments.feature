Feature: Course Assignments

	Background:
		Given a course exists

	Scenario: Student doesn't see disabled assignment
		Given I'm logged in as a student
		When I go to the Request Extension page
		Then I should not see "Homework 1"

	Scenario: Student sees only enabled assignments
		Given I'm logged in as a teacher
		When I go to the Course page
		And I enable "Homework 2"
		Then I log in as a student
		And I go to the Course page
		Then I should not see "Homework 1"
		Then I should see "Homework 2"

	Scenario: Instructor sees the Sync Assignments button and last synced time
		Given I'm logged in as a teacher
		When I go to the Course page
		Then I should see "Sync Assignments"
		And I should see "Assignments last synced at"

	@javascript
	Scenario: Clicking Sync Assignments disables the button and shows a spinner
		Given I'm logged in as a teacher
		When I go to the Course page
		And I click the "Sync Assignments" button
		Then the "Sync Assignments" button should be disabled
		And I should see a loading spinner

	@javascript
	Scenario: Assignments are listed by due date, soonest first
		Given the course has assignments:
			| name   | due date            |
			| Lab 2  | 2026-09-04 17:00:00 |
			| Lab 9  | 2026-08-31 17:00:00 |
			| Lab 10 | 2026-09-01 17:00:00 |
		And I'm logged in as a teacher
		When I go to the Course page
		Then the "assignments-table" rows should be in the order "Lab 9, Lab 10, Lab 2"

	@javascript
	Scenario: Sorting by due date is chronological, not alphabetical
		Given the course has assignments:
			| name   | due date            |
			| Lab 2  | 2026-09-04 17:00:00 |
			| Lab 9  | 2026-08-31 17:00:00 |
			| Lab 10 | 2026-09-01 17:00:00 |
		And I'm logged in as a teacher
		When I go to the Course page
		And I sort the "assignments-table" by "Due Date" descending
		Then the "assignments-table" rows should be in the order "Lab 2, Lab 10, Lab 9"

	@javascript
	Scenario: Sorting by assignment name counts numbers, so Lab 9 comes before Lab 10
		Given the course has assignments:
			| name   | due date            |
			| Lab 2  | 2026-09-04 17:00:00 |
			| Lab 9  | 2026-08-31 17:00:00 |
			| Lab 10 | 2026-09-01 17:00:00 |
		And I'm logged in as a teacher
		When I go to the Course page
		And I sort the "assignments-table" by "Assignment" ascending
		Then the "assignments-table" rows should be in the order "Lab 2, Lab 9, Lab 10"

	@javascript
	Scenario: Assignments without a due date are listed last
		Given the course has assignments:
			| name   | due date            |
			| Lab 2  |                     |
			| Lab 9  | 2026-08-31 17:00:00 |
			| Lab 10 | 2026-09-01 17:00:00 |
		And I'm logged in as a teacher
		When I go to the Course page
		Then the "assignments-table" rows should be in the order "Lab 9, Lab 10, Lab 2"
