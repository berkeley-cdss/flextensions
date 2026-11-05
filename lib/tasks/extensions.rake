# frozen_string_literal: true

namespace :extensions do
  desc 'List approved extensions that end before the current deadline. Read-only. ' \
       'Usage: bin/rails extensions:report_stale'
  task report_stale: :environment do
    stale = Request.approved_before_current_deadline.includes(:assignment, :course)

    if stale.empty?
      puts 'No approved extensions end before their current deadline.'
      next
    end

    stale.group_by(&:course).each do |course, requests|
      puts "Course #{course.id}: #{course.course_name}"
      requests.group_by(&:assignment).each do |assignment, assignment_requests|
        students = assignment_requests.map(&:user_id).uniq.size
        puts "  #{assignment.name} (due #{assignment.due_date.iso8601}): #{students} student(s)"
      end
    end
    puts 'These requests stay listed after a repair, because the removal only changes the LMS. ' \
         "See each course's page for the results of its latest sync."
  end

  desc 'Sync assignments for affected courses, which removes outdated extensions from the LMS. ' \
       'Run extensions:report_stale first. Usage: bin/rails "extensions:repair_stale[12,34]" or "extensions:repair_stale[all]"'
  task repair_stale: :environment do |_task, args|
    targets = args.to_a
    abort 'Usage: bin/rails "extensions:repair_stale[12,34]" or "extensions:repair_stale[all]"' if targets.empty?

    affected = Request.approved_before_current_deadline.distinct.pluck('requests.course_id')
    course_ids = targets == [ 'all' ] ? affected : targets.map(&:to_i) & affected

    Course.where(id: course_ids).find_each do |course|
      sync_user = AutomaticEnrollmentSyncJob.sync_user_for(course, require_fresh_token: true)
      if sync_user
        course.sync_assignments(sync_user)
        puts "Queued a sync for course #{course.id}: #{course.course_name}"
      else
        puts "Skipped course #{course.id}: #{course.course_name} (no staff member has working Canvas access)"
      end
    end
  end
end
