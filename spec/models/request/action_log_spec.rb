require 'rails_helper'

RSpec.describe Request::ActionLog do
  let(:staff) { create(:user, name: 'Grace Hopper') }
  let(:course) { create(:course) }
  let(:request) { create(:request, course: course, assignment: course.assignments.first) }

  describe '#log_action' do
    it 'starts with an empty log' do
      expect(request.action_log).to eq([])
      expect(request.action_log_entries).to eq([])
    end

    it 'saves the entry immediately with its time, actor, and message' do
      freeze_time do
        request.log_action(:approval_failed, 'Canvas said no', actor: staff)

        expect(request.reload.action_log).to eq([
          { 'action' => 'approval_failed', 'at' => Time.current.iso8601, 'actor_id' => staff.id,
            'actor_name' => 'Grace Hopper', 'message' => 'Canvas said no' }
        ])
      end
    end

    it 'leaves out the actor and message when there are none' do
      request.log_action(:auto_approval_skipped)

      expect(request.reload.action_log.last.keys).to contain_exactly('action', 'at')
    end

    it 'keeps entries in the order they were logged' do
      request.log_action(:approval_failed, 'first')
      request.log_action(:denied, 'second')

      expect(request.reload.action_log_entries.map(&:message)).to eq(%w[first second])
    end

    it 'does not leave the record dirty' do
      request.log_action(:denied)

      expect(request).not_to be_changed
    end

    it 'does not overwrite an entry another process added in the meantime' do
      stale_copy = Request.find(request.id)
      request.log_action(:approval_failed, 'from one process')

      stale_copy.log_action(:approval_failed, 'from another process')

      expect(request.reload.action_log_entries.map(&:message)).to eq([ 'from one process', 'from another process' ])
    end

    it 'records the entry even when the request no longer passes validation' do
      request.update_column(:reason, nil) # rubocop:disable Rails/SkipsModelValidations

      request.log_action(:approval_failed, 'still recorded')

      expect(request.reload.action_log_entries.last.message).to eq('still recorded')
    end

    it 'holds the entry on an unsaved request until it is saved' do
      unsaved = build(:request, course: course, assignment: course.assignments.first, user: staff)

      unsaved.log_action(:denied, 'before save')
      unsaved.save!

      expect(unsaved.reload.action_log_entries.last.message).to eq('before save')
    end
  end

  describe '#action_log_entries' do
    it 'presents each entry with a readable label and a real time' do
      freeze_time do
        request.log_action(:auto_approved, 'Extension created', actor: staff)

        entry = request.action_log_entries.last
        expect(entry.label).to eq('Auto-approved')
        expect(entry.at).to eq(Time.current)
        expect(entry.actor_name).to eq('Grace Hopper')
        expect(entry).not_to be_failure
      end
    end

    it 'marks failed approvals as failures' do
      request.log_action(:approval_failed)
      request.log_action(:auto_approval_failed)

      expect(request.action_log_entries).to all be_failure
    end
  end

  describe '#unresolved_failure' do
    it 'is nil for a request with nothing logged' do
      expect(request.unresolved_failure).to be_nil
    end

    it 'is the latest entry when that entry is a failure' do
      request.log_action(:auto_approval_skipped, 'too many days')
      request.log_action(:approval_failed, 'Canvas said no')

      expect(request.unresolved_failure.message).to eq('Canvas said no')
    end

    it 'is nil once a later action has settled the request' do
      request.log_action(:approval_failed, 'Canvas said no')
      request.log_action(:approved)

      expect(request.unresolved_failure).to be_nil
    end
  end
end
