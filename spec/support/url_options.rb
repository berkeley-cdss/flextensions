# Links in notifications are built against the app-wide default_url_options,
# resolved once at boot from APP_HOST (see
# config/initializers/default_url_options.rb). Specs that assert on a link say
# which origin they expect rather than depending on the developer's .env:
#
#   describe '#request_link', app_origin: 'https://flextensions.example.com' do
RSpec.configure do |config|
  config.around(:each, :app_origin) do |example|
    routes = Rails.application.routes
    previous = routes.default_url_options
    previous_asset_host = ActionMailer::Base.asset_host
    routes.default_url_options = { host: example.metadata[:app_origin] }
    ActionMailer::Base.default_url_options = routes.default_url_options
    ActionMailer::Base.asset_host = example.metadata[:app_origin]

    example.run
  ensure
    routes.default_url_options = previous
    ActionMailer::Base.default_url_options = previous
    ActionMailer::Base.asset_host = previous_asset_host
  end
end
