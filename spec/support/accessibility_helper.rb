# spec/support/accessibility_helper.rb
require 'axe-rspec'

# Shared support for accessibility (a11y) auditing in Capybara + RSpec feature
# specs.
#
# Any feature-spec example tagged with `:a11y` automatically has its final
# rendered page audited with axe-core through the `after` hook configured
# below. Individual examples therefore only need to drive the browser to the
# page under test -- they should not repeat `expect(page).to be_axe_clean`.
module AccessibilityHelper
  # Audit the current Capybara page with axe-core and fail the example on any
  # WCAG violation. Kept as a helper so individual specs can also invoke it
  # explicitly (e.g. to audit an intermediate page mid-example).
  def audit_page_accessibility
    expect(page).to be_axe_clean
  end
end

RSpec.configure do |config|
  config.include AccessibilityHelper, type: :feature

  # Use a large, consistent viewport so responsive/off-canvas elements are
  # rendered before the audit runs.
  config.before(:each, :a11y, type: :feature) do
    page.driver.browser.manage.window.resize_to(1400, 1400) if page.driver.browser.respond_to?(:manage)
  end

  # The three `after` hooks below are intentionally split so that ordering is
  # explicit. RSpec runs `after(:each)` hooks in reverse of their definition
  # order, so the last one defined (the audit) runs first, while the page and
  # Selenium session are still live; teardown then follows.
  #
  # Runtime order: audit -> reset session -> re-enable WebMock blocking.

  # Runs last: restore WebMock's default (blocked) network state.
  config.after(:each, :a11y, type: :feature) do
    WebMock.disable_net_connect!(allow_localhost: true) if defined?(WebMock)
  end

  # Runs second: tear down the browser session.
  config.after(:each, :a11y, type: :feature) do
    Capybara.reset_sessions!
  rescue Selenium::WebDriver::Error::NoSuchWindowError,
         Selenium::WebDriver::Error::InvalidSessionIdError,
         Selenium::WebDriver::Error::UnknownError
    # Ignore browser teardown races -- the audit has already run.
  end

  # Runs first: audit the final rendered page for accessibility violations.
  config.after(:each, :a11y, type: :feature) do
    audit_page_accessibility
  end
end
