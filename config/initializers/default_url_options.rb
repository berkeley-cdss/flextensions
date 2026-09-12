# frozen_string_literal: true

# The origin that generated links point at.
#
# Notifications are read outside the browser, so their links have to be
# absolute: a bare "/courses/19/requests/26" is what a mail client renders as
# "http:///courses/19/requests/26". A mailer or a background job has no
# incoming request to take a host from, so it comes from configuration:
#
#   1. APP_HOST -- the full domain this deployment is reached at, optionally
#      with a scheme and port. APP_PORT supplies the port when it does not.
#   2. CANVAS_REDIRECT_URI -- the same origin by definition, since Canvas
#      redirects browsers back to this app, and set wherever login works.
#   3. localhost, so links are at least well formed.
#
# Rails picks the scheme, host and port back out of `host:` itself (see
# ActionDispatch::Http::URL::HOST_REGEXP), so the origin stays one string.

# APP_PORT is the port the app process listens on, which is not the port users
# connect to when TLS is terminated in front of it -- only a non-standard port
# belongs in a link.
app_port = ENV["APP_PORT"].presence
app_port = nil if [ "80", "443" ].include?(app_port)

app_host = ENV["APP_HOST"].presence&.strip
app_host = "#{app_host}:#{app_port}" if app_host && app_port && !app_host.match?(/:\d+\z/)

origin = app_host || ENV["CANVAS_REDIRECT_URI"].presence&.strip&.chomp("/") || "localhost:3000"
# Deployments are served over TLS, local development is not.
unless origin.include?("://")
  local = origin.match?(%r{\A(localhost|127\.0\.0\.1|[^/]+\.(lvh\.me|localhost|test))(:\d+)?\z})
  origin = "#{local ? 'http' : 'https'}://#{origin}"
end

Rails.application.routes.default_url_options = { host: origin }

# Assign inside `on_load`: referencing ActionMailer::Base here loads Action
# Mailer during initializers, running `register_interceptors` before Zeitwerk
# can autoload app/. Staging sets StagingEmailInterceptor, so it died at boot
# with `uninitialized constant StagingEmailInterceptor`.
ActiveSupport.on_load(:action_mailer) do
  self.default_url_options = { host: origin }
end

# Nobody notices the wrong host until a notification lands in an inbox pointing
# somewhere unreachable, so say so at boot instead.
if ENV["APP_HOST"].blank?
  Rails.logger.warn("APP_HOST is not set, so links in notifications point at #{origin}. " \
                    "Set it to the full domain this server is reached at.")
end
