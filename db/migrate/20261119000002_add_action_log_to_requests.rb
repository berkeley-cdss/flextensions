# action_log is a per-request history of what was done to the request and why:
# approvals, denials, LMS failures, and the reason a request was not
# auto-approved. It is an array of entries (see Request::ActionLog) kept in one
# jsonb column so each entry carries its own time and actor.
class AddActionLogToRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :requests, :action_log, :jsonb, default: [], null: false
  end
end
