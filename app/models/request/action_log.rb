# The per-request action log: a running history of what was done to a request
# and why. Approvals and denials are recorded here, and so are the things that
# otherwise leave no trace on the request -- an approval the LMS refused, or
# the reason a request was not auto-approved -- so course staff can see why a
# request is in the state it is in.
#
# The log lives in the requests.action_log jsonb column as an array of
# entries, oldest first. Each entry is a hash with string keys:
#
#   'action'     - what happened; one of the keys of ACTION_LABELS
#   'at'         - when, as an ISO 8601 timestamp
#   'actor_id'   - id of the user who did it, when someone did
#   'actor_name' - that user's name at the time, so the log still reads
#                  correctly if they are renamed or removed
#   'message'    - optional detail, e.g. the error the LMS returned
module Request::ActionLog
  extend ActiveSupport::Concern

  # Every action that can be logged, with the label staff see for it.
  ACTION_LABELS = {
    'approved' => 'Approved',
    'auto_approved' => 'Auto-approved',
    'denied' => 'Denied',
    'canceled' => 'Canceled',
    'approval_failed' => 'Approval failed',
    'auto_approval_failed' => 'Auto-approval failed',
    'auto_approval_skipped' => 'Not auto-approved'
  }.freeze

  # Actions that mean something went wrong and staff need to step in.
  FAILURE_ACTIONS = %w[approval_failed auto_approval_failed].freeze

  # One log entry, for display.
  Entry = Struct.new(:action, :at, :actor_name, :message, keyword_init: true) do
    def label
      ACTION_LABELS.fetch(action, action.to_s.humanize)
    end

    def failure?
      FAILURE_ACTIONS.include?(action)
    end
  end

  # The log as Entry objects, oldest first.
  def action_log_entries
    action_log.map { |entry| build_action_log_entry(entry) }
  end

  # The failure staff still need to deal with: the most recent entry, when it
  # is a failure. A later approval or denial settles the request, so an older
  # failure further up the log no longer counts.
  def unresolved_failure
    latest = action_log.last
    build_action_log_entry(latest) if latest && FAILURE_ACTIONS.include?(latest['action'])
  end

  # Appends an entry to the log and saves it straight away, on its own. The
  # append happens in the database rather than by writing back the whole array,
  # so an entry added by another process in the meantime is not overwritten,
  # and it skips validations so a failure can always be recorded.
  def log_action(action, message = nil, actor: nil)
    entry = {
      'action' => action.to_s,
      'at' => Time.current.iso8601,
      'actor_id' => actor&.id,
      'actor_name' => actor&.name,
      'message' => message
    }.compact

    if persisted?
      self.class.where(id: id).update_all( # rubocop:disable Rails/SkipsModelValidations
        [ 'action_log = action_log || ?::jsonb, updated_at = ?', [ entry ].to_json, Time.current ]
      )
      self.action_log += [ entry ]
      clear_attribute_changes([ :action_log ])
    else
      self.action_log += [ entry ]
    end
    entry
  end

  private

  def build_action_log_entry(entry)
    Entry.new(
      action: entry['action'],
      at: Time.zone.parse(entry['at'].to_s),
      actor_name: entry['actor_name'],
      message: entry['message']
    )
  end
end
