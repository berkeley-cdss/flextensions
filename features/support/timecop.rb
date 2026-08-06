# frozen_string_literal: true

require 'timecop'

# Scenarios tagged @freeze_time run with the clock frozen for their duration.
#
# Several steps assert that a date rendered on the page (built from a factory's
# `N.days.from_now`, captured when the record was created) matches a value the
# step recomputes as `Time.zone.now + N.days` at assertion time. When the wall
# clock crosses a minute boundary between those two moments the formatted
# timestamps differ and the scenario fails intermittently. Freezing the clock
# makes both moments resolve to the same instant, so the comparison is stable.
#
# Capybara/Selenium wait timeouts use a monotonic clock (Process.clock_gettime),
# which Timecop does not stub, so freezing is safe for @javascript scenarios too.
Before('@freeze_time') do
  Timecop.freeze
end

After('@freeze_time') do
  Timecop.return
end
