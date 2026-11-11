require 'rails_helper'
require 'rake'

RSpec.describe 'extensions rake tasks' do # rubocop:disable RSpec/DescribeClass
  let(:course) { create(:course, :with_staff, course_name: 'CS 61C') }
  let(:assignment) do
    create(:assignment, course_to_lms: course.course_to_lms(1), name: 'HW 1', due_date: 1.day.from_now)
  end
  let(:student) { create(:user) }

  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?('extensions:report_stale')
  end

  def run_task(name, *args)
    Rake::Task[name].reenable
    Rake::Task[name].invoke(*args)
  end

  def create_stale_extension
    create(:request, :approved, course: course, assignment: assignment, user: student,
                                requested_due_date: 2.days.from_now)
    assignment.update!(due_date: 20.days.from_now)
  end

  describe 'extensions:report_stale' do
    it 'says so when nothing is affected' do
      expect { run_task('extensions:report_stale') }.to output(/No approved extensions/).to_stdout
    end

    it 'lists the affected courses and assignments' do
      create_stale_extension

      expect { run_task('extensions:report_stale') }
        .to output(/Course #{course.id}: CS 61C\n  HW 1 \(due .*\): 1 student/).to_stdout
    end

    it 'does not change anything' do
      create_stale_extension
      allow(SyncAllCourseAssignmentsJob).to receive(:perform_later)

      expect { run_task('extensions:report_stale') }.to output.to_stdout
      expect(SyncAllCourseAssignmentsJob).not_to have_received(:perform_later)
    end
  end

  describe 'extensions:repair_stale' do
    let(:sync_user) { course.staff_users.first }

    before do
      create_stale_extension
      allow(AutomaticEnrollmentSyncJob).to receive(:sync_user_for).and_return(sync_user)
      allow(SyncAllCourseAssignmentsJob).to receive(:perform_later)
    end

    it 'requires the courses to be named' do
      expect { run_task('extensions:repair_stale') }.to raise_error(SystemExit).and output(/Usage/).to_stderr
    end

    it 'queues a sync for every affected course with "all"' do
      expect { run_task('extensions:repair_stale', 'all') }.to output(/Queued a sync for course #{course.id}/).to_stdout
      expect(SyncAllCourseAssignmentsJob).to have_received(:perform_later).with(course.course_to_lms(1).id, sync_user.id)
    end

    it 'queues a sync for a named course' do
      expect { run_task('extensions:repair_stale', course.id.to_s) }.to output(/Queued/).to_stdout
      expect(SyncAllCourseAssignmentsJob).to have_received(:perform_later).once
    end

    it 'ignores a named course with nothing to repair' do
      unaffected = create(:course)

      expect { run_task('extensions:repair_stale', unaffected.id.to_s) }.not_to output.to_stdout
      expect(SyncAllCourseAssignmentsJob).not_to have_received(:perform_later)
    end

    it 'skips a course with no working staff access' do
      allow(AutomaticEnrollmentSyncJob).to receive(:sync_user_for).and_return(nil)

      expect { run_task('extensions:repair_stale', 'all') }.to output(/Skipped course #{course.id}/).to_stdout
      expect(SyncAllCourseAssignmentsJob).not_to have_received(:perform_later)
    end
  end
end
