require 'rails_helper'

RSpec.describe DeploymentInfo do
  let(:sha) { 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2' }

  # The module memoizes on itself, so the memos have to be cleared both before
  # (to ignore whatever the app already resolved) and after (so stubbed values
  # do not leak into later specs that render the footer).
  def clear_memos
    described_class.instance_variables.each { |ivar| described_class.remove_instance_variable(ivar) }
  end

  before do
    clear_memos
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('DEPLOY_TIMESTAMP').and_return(nil)
    allow(ENV).to receive(:[]).with('GIT_COMMIT').and_return(nil)
    allow(ENV).to receive(:[]).with('HEROKU_SLUG_COMMIT').and_return(nil)
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(Rails.root.join('DEPLOYED_AT')).and_raise(Errno::ENOENT)
    allow(File).to receive(:read).with(Rails.root.join('REVISION')).and_raise(Errno::ENOENT)
    allow(described_class).to receive(:local_git_commit).and_return(nil)
  end

  after { clear_memos }

  describe '.deployed_at' do
    it 'parses an ISO 8601 DEPLOY_TIMESTAMP' do
      allow(ENV).to receive(:[]).with('DEPLOY_TIMESTAMP').and_return('2026-08-05T17:30:00Z')

      expect(described_class.deployed_at).to eq(Time.utc(2026, 8, 5, 17, 30))
    end

    it 'parses a Unix epoch DEPLOY_TIMESTAMP' do
      allow(ENV).to receive(:[]).with('DEPLOY_TIMESTAMP').and_return('1785000000')

      expect(described_class.deployed_at).to eq(Time.zone.at(1_785_000_000))
    end

    it 'falls back to the DEPLOYED_AT file stamped in by the build' do
      allow(File).to receive(:read).with(Rails.root.join('DEPLOYED_AT')).and_return("2026-07-04T12:00:00Z\n")

      expect(described_class.deployed_at).to eq(Time.utc(2026, 7, 4, 12, 0))
    end

    it 'is nil when nothing is available' do
      expect(described_class.deployed_at).to be_nil
    end

    it 'ignores an unparseable timestamp' do
      allow(ENV).to receive(:[]).with('DEPLOY_TIMESTAMP').and_return('not a time')

      expect(described_class.deployed_at).to be_nil
    end

    # A `%Y%m%d%H%M%S` stamp or milliseconds would otherwise be read as epoch
    # seconds and render a date tens of thousands of years out.
    it 'ignores a digit string that is not plausibly epoch seconds' do
      allow(ENV).to receive(:[]).with('DEPLOY_TIMESTAMP').and_return('20260805173000')

      expect(described_class.deployed_at).to be_nil
    end

    it 'memoizes so the footer does not re-read on every render' do
      allow(ENV).to receive(:[]).with('DEPLOY_TIMESTAMP').and_return('2026-08-05T17:30:00Z')

      2.times { described_class.deployed_at }

      expect(ENV).to have_received(:[]).with('DEPLOY_TIMESTAMP').once
    end
  end

  describe '.commit' do
    it 'prefers GIT_COMMIT' do
      allow(ENV).to receive(:[]).with('GIT_COMMIT').and_return(sha)

      expect(described_class.commit).to eq(sha)
      expect(described_class.short_commit).to eq('a1b2c3d')
      expect(described_class.commit_url).to eq("#{described_class::REPO_URL}/commit/#{sha}")
    end

    it 'falls back to the REVISION file' do
      allow(File).to receive(:read).with(Rails.root.join('REVISION')).and_return("#{sha}\n")

      expect(described_class.commit).to eq(sha)
    end

    it 'falls back to local git in development' do
      allow(described_class).to receive(:local_git_commit).and_return(sha)

      expect(described_class.commit).to eq(sha)
    end

    # .ebextensions writes the literal "unknown" when REVISION is missing.
    it 'rejects a placeholder that is not a SHA' do
      allow(ENV).to receive(:[]).with('GIT_COMMIT').and_return('unknown')

      expect(described_class.commit).to be_nil
      expect(described_class.short_commit).to be_nil
      expect(described_class.commit_url).to be_nil
    end

    it 'is nil when nothing is available' do
      expect(described_class.commit).to be_nil
      expect(described_class.short_commit).to be_nil
      expect(described_class.commit_url).to be_nil
    end

    it 'memoizes the miss so it does not shell out on every render' do
      2.times { described_class.commit }

      expect(described_class).to have_received(:local_git_commit).once
    end
  end
end
