# frozen_string_literal: true

namespace :lms_credentials do
  desc 'Delete stored LMS credentials (default: canvas) so users re-authenticate. ' \
       'Run after changing the Canvas developer key or its scopes, which invalidates ' \
       'every token derived from the key. Usage: bin/rails "lms_credentials:purge[canvas]"'
  task :purge, [ :lms_name ] => :environment do |_task, args|
    lms_name = args[:lms_name] || 'canvas'
    count = LmsCredential.where(lms_name: lms_name).delete_all
    puts "Deleted #{count} #{lms_name} credential(s). " \
         'Users will re-authenticate automatically on their next visit; auto-approval in each ' \
         'course resumes once one of its staff members has logged in.'
  end
end
