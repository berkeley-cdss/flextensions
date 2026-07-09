# frozen_string_literal: true

require 'cgi'

OmniAuth::Strategies::Canvas.class_eval do
  def build_access_token
    verifier = request.params['code']
    client.auth_code.get_token(
      verifier,
      { redirect_uri: callback_url, scope: CanvasFacade::CANVAS_API_SCOPES },
      deep_symbolize(options.auth_token_params)
    )
  end
end


Rails.application.config.middleware.use OmniAuth::Builder do
  # URL-encode the scopes defined in CanvasFacade
  encoded_scopes = CGI.escape(CanvasFacade::CANVAS_API_SCOPES)

  provider :developer, fields: [:email] if Rails.env.local?

  provider :canvas,
          ENV['CANVAS_CLIENT_ID'],
          ENV['CANVAS_APP_KEY'],
          client_options: {
            site: ENV['CANVAS_URL'],
            authorize_url: "/login/oauth2/auth?scope=#{encoded_scopes}"
          },
          redirect_uri: "#{ENV['CANVAS_REDIRECT_URI']}/auth/canvas/callback"
end

# OmniAuth.config.before_request_phase do |env|
#   Rails.logger.debug "AUTH URL: #{env['omniauth.strategy'].client.auth_code.authorize_url(authorize_params: env['omniauth.strategy'].authorize_params)}"
# end

# Only allow POST to initiate the OmniAuth request phase. Combined with the
# omniauth-rails_csrf_protection gem (which verifies the Rails CSRF token on
# that request), this closes the CVE-2015-9284 login CSRF hole that a GET
# request phase would otherwise expose.
OmniAuth.config.allowed_request_methods = [:post]

OmniAuth.config.on_failure = Proc.new do |env|
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
end
