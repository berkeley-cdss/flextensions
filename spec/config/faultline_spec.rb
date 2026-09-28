require 'rails_helper'

# The initializer in config/initializers/faultline.rb is the only place error
# notifications are wired up, so pin the parts the team relies on.
RSpec.describe 'Faultline configuration' do # rubocop:disable RSpec/DescribeClass
  let(:config) { Faultline.configuration }

  it 'emails the team about new errors' do
    email_notifiers = config.notifiers.select { |n| n.is_a?(Faultline::Notifiers::Email) }

    expect(email_notifiers.size).to eq(1)
    expect(email_notifiers.first.instance_variable_get(:@to)).to eq([ 'flextensions@berkeley.edu' ])
  end

  it 'notifies on first occurrence of an error group' do
    expect(config.notification_rules[:on_first_occurrence]).to be true
  end

  it 'subscribes to the Rails error reporter so job errors are tracked' do
    expect(config.register_error_subscriber).to be true
  end

  describe 'dashboard' do
    it 'is mounted at /admin/faultline' do
      expect(Rails.application.routes.url_helpers.faultline_path).to eq('/admin/faultline')
    end

    it 'does not track its own requests or the load balancer health check' do
      expect(config.middleware_ignore_paths).to include('/admin/faultline', '/status/health_check')
      expect(config.middleware_ignore_paths).not_to include('/admin/errors')
    end
  end

  describe 'user identification' do
    it "records the controller's current_user on each occurrence" do
      expect(config.user_class).to eq('User')
      expect(config.user_method).to eq(:current_user)
    end

    it 'attaches the Canvas uid from the session as context' do
      request = instance_double(ActionDispatch::Request, session: { user_id: '12345' })

      expect(config.custom_context.call(request, {})).to eq(canvas_uid: '12345')
    end

    it 'adds no context for anonymous requests' do
      request = instance_double(ActionDispatch::Request, session: {})

      expect(config.custom_context.call(request, {})).to eq({})
    end
  end

  describe 'duplicate suppression' do
    let(:before_track) { config.before_track }

    it "drops ActionDispatch's re-report of an exception the middleware already tracked" do
      expect(before_track.call(StandardError.new, source: 'application.action_dispatch')).to be false
    end

    it 'keeps errors from jobs and explicit Rails.error calls' do
      expect(before_track.call(StandardError.new, source: 'application.active_job')).to be true
      expect(before_track.call(StandardError.new, source: 'good_job')).to be true
      expect(before_track.call(StandardError.new, source: 'application')).to be true
    end

    it 'keeps errors tracked by the middleware itself' do
      expect(before_track.call(StandardError.new, request: nil, user: nil)).to be true
    end
  end

  describe 'APM' do
    it 'is enabled' do
      expect(config.enable_apm).to be true
    end

    it 'samples 30% of requests' do
      expect(config.apm_sample_rate).to eq(0.3)
    end

    it 'skips the load balancer health check and its own dashboard' do
      expect(config.resolved_apm_ignore_paths).to include('/status/health_check', '/admin/faultline')
    end

    it 'keeps traces for 30 days and errors for 90' do
      expect(config.apm_retention_days).to eq(30)
      expect(config.retention_days).to eq(90)
    end
  end
end
