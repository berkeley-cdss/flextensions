# Be sure to restart your server when you modify this file.

# By default Rails uses a "session" cookie that is cleared as soon as the
# browser is closed, which causes users to be logged out far too often.
#
# Giving the cookie an explicit `expire_after` lets the browser persist the
# session across restarts so people stay logged in for the lifetime of the
# cookie (as long as their Canvas refresh token is still valid). Combined with
# refreshing the Canvas access token on expiry (see ApplicationController),
# this keeps sessions alive much longer.
Rails.application.config.session_store :cookie_store,
                                       key: '_flextensions_session',
                                       expire_after: 3.days
