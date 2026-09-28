# frozen_string_literal: true

# Base class for all application mailers. Every email is wrapped in the shared
# layout in app/views/layouts/mailer.{html,text}.erb.
class ApplicationMailer < ActionMailer::Base
  layout 'mailer'
end
