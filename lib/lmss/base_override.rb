module Lmss
  class BaseOverride
    def id = raise(NotImplementedError)
    # The students an override targets. Canvas adhoc overrides target a list,
    # Gradescope overrides a single student; both answer this as an array so
    # callers can treat overrides uniformly.
    def student_ids = raise(NotImplementedError)
    def override_release_date = raise(NotImplementedError)
    def override_due_date = raise(NotImplementedError)
    def override_late_due_date = raise(NotImplementedError)
  end
end
