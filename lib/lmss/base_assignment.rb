module Lmss
  class BaseAssignment
    def id = raise(NotImplementedError)
    def name = raise(NotImplementedError)
    def due_date = raise(NotImplementedError)
    def late_due_date = raise(NotImplementedError)

    # Number of per-student/section date overrides on this assignment.
    # Defaults to 0 for LMSes that do not expose overrides.
    def overrides_count = 0

    # Whether the LMS returned an explicit base (non-override) due date.
    # Defaults to true for LMSes without a base/override date distinction.
    def base_date? = true
  end
end
