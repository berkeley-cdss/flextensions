require 'rails_helper'

# Mailers and notification jobs render links with no incoming request to take a
# host from, so the app-wide defaults have to name one -- otherwise Rails emits
# bare paths and mail clients turn them into "http:///courses/19".
RSpec.describe 'default URL options' do # rubocop:disable RSpec/DescribeClass
  # Re-runs the initializer under a given environment and reports the origin it
  # settles on, restoring what the real boot configured.
  def origin_for(app_host: nil, app_port: nil, canvas_redirect_uri: nil)
    routes = Rails.application.routes
    previous = routes.default_url_options
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('APP_HOST').and_return(app_host)
    allow(ENV).to receive(:[]).with('APP_PORT').and_return(app_port)
    allow(ENV).to receive(:[]).with('CANVAS_REDIRECT_URI').and_return(canvas_redirect_uri)

    load Rails.root.join('config/initializers/default_url_options.rb')
    routes.default_url_options[:host]
  ensure
    routes.default_url_options = previous
    ActionMailer::Base.default_url_options = previous
  end

  describe 'the origin links are built against' do
    it 'assumes https for a bare domain, since deployments are served over TLS' do
      expect(origin_for(app_host: 'flextensions.eecs.cloud')).to eq('https://flextensions.eecs.cloud')
    end

    it 'keeps the scheme and port given in APP_HOST' do
      expect(origin_for(app_host: 'http://localhost:3000')).to eq('http://localhost:3000')
    end

    it 'appends APP_PORT when APP_HOST carries no port' do
      expect(origin_for(app_host: 'localhost', app_port: '3000')).to eq('http://localhost:3000')
    end

    it 'leaves out the port the app listens on when browsers assume it anyway' do
      expect(origin_for(app_host: 'flextensions.eecs.cloud', app_port: '80'))
        .to eq('https://flextensions.eecs.cloud')
    end

    it 'falls back to the Canvas redirect URI, which is the same origin' do
      expect(origin_for(app_host: '', canvas_redirect_uri: 'https://flextensions.eecs.cloud/'))
        .to eq('https://flextensions.eecs.cloud')
    end

    it 'still names an origin when nothing is configured' do
      expect(origin_for).to eq('http://localhost:3000')
    end
  end

  describe 'the boot-time warning' do
    it 'warns when APP_HOST is not set' do
      allow(Rails.logger).to receive(:warn)

      origin_for(canvas_redirect_uri: 'https://flextensions.eecs.cloud')

      expect(Rails.logger).to have_received(:warn).with(/APP_HOST is not set/)
    end

    it 'warns when APP_HOST is empty rather than missing' do
      allow(Rails.logger).to receive(:warn)

      origin_for(app_host: '  ')

      expect(Rails.logger).to have_received(:warn).with(/APP_HOST is not set/)
    end

    it 'stays quiet when APP_HOST is set' do
      allow(Rails.logger).to receive(:warn)

      origin_for(app_host: 'flextensions.eecs.cloud')

      expect(Rails.logger).not_to have_received(:warn)
    end
  end

  describe 'what the running app booted with' do
    it 'gives mailers the same origin as route helpers' do
      expect(ActionMailer::Base.default_url_options).to eq(Rails.application.routes.default_url_options)
    end

    it 'is enough for a _url helper to produce an absolute URL' do
      expect(Rails.application.routes.url_helpers.root_url).to match(%r{\Ahttps?://.+/\z})
    end
  end
end
