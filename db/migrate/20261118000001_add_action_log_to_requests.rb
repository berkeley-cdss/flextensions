# action_log is a per-request history of what was done to the request and why:
# approvals, denials, LMS failures, and the reason a request was not
# auto-approved. It is an array of entries (see Request::ActionLog) kept in one
# jsonb column so each entry carries its own time and actor.
#
# last_action_at is when the request was last approved or denied. Until now
# updated_at stood in for that, but updated_at also moves on unrelated writes.
class AddActionLogToRequests < ActiveRecord::Migration[8.1]
  class MigrationRequest < ActiveRecord::Base
    self.table_name = 'requests'
  end

  def up
    add_column :requests, :action_log, :jsonb, default: [], null: false
    add_column :requests, :last_action_at, :datetime

    # updated_at is the best record we have of when existing requests were decided.
    MigrationRequest.where.not(status: 'pending').update_all('last_action_at = updated_at')
  end

  def down
    remove_column :requests, :last_action_at
    remove_column :requests, :action_log
  end
end
