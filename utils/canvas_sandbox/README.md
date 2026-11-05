# Canvas sandbox approval testing

Rerunnable scripts for exercising Flextensions' extension-approval flows
against a real Canvas instance (by default the UC Berkeley sandbox,
`https://ucberkeleysandbox.instructure.com`).

Both scripts read the Canvas API token from the `CANVAS_TOKEN` environment
variable. **Never commit or hardcode a token.**

## 1. `setup_test_course.rb` — create/refresh the Canvas test data

```sh
CANVAS_TOKEN=<token> ruby utils/canvas_sandbox/setup_test_course.rb
```

Ensures the test course (default `CANVAS_COURSE_ID=146`,
[Flextensions Test Course](https://ucberkeleysandbox.instructure.com/courses/146))
contains one of each assignment type Flextensions must support, with due dates
~30 days in the future (rerun any time the dates go stale):

- [Flextensions Test Assignment (regular)](https://ucberkeleysandbox.instructure.com/courses/146/assignments/208)
- [Flextensions Test Quiz (classic)](https://ucberkeleysandbox.instructure.com/courses/146/assignments/207)
- [Flextensions Test Discussion (graded)](https://ucberkeleysandbox.instructure.com/courses/146/assignments/206)

The course roster's `*.example.com` students are used as test students.

## 2. `test_approval_flows.rb` — end-to-end approval scenarios

```sh
CANVAS_TOKEN=<token> CANVAS_URL=https://ucberkeleysandbox.instructure.com \
  bin/rails runner utils/canvas_sandbox/test_approval_flows.rb
```

Runs the real application code (`Request#process_created_request`,
`Request#approve`, `CanvasFacade#provision_extension`) against the sandbox,
using a local development database seeded to mirror the test course. For each
of the three assignment types it verifies:

- **AUTO** — a request within `auto_approve_days` is auto-approved and the
  override appears in Canvas with the right due date.
- **MANUAL** — a request outside `auto_approve_days` stays pending, then is
  approved with a staff user's facade and appears in Canvas.
- **GROUP** — a second student with the same extension length joins the first
  student's override group instead of getting a new override.

It then replays two production failure modes and asserts auto-approval still
succeeds by falling back to another staff user:

- **NOCREDS** — the course's first staff member has no Canvas credentials at
  all (a TA synced from the Canvas roster who never logged into Flextensions).
- **STALE** — the preferred staff member has credentials, but they are expired
  and cannot be refreshed (Canvas revokes refresh tokens that go unused for
  months). The refresh attempt is made for real against the Canvas OAuth
  endpoint and fails, exercising the staff failover path end to end.

The script cleans up the Canvas overrides it created; pass `KEEP_OVERRIDES=1`
to leave them in place for manual inspection.

## 3. `test_moved_deadline.rb` — extensions after a deadline moves

```sh
CANVAS_TOKEN=<token> CANVAS_URL=https://ucberkeleysandbox.instructure.com \
  bin/rails runner utils/canvas_sandbox/test_moved_deadline.rb
```

Runs the real application code (`Request#approve`,
`SyncAllCourseAssignmentsJob`, `StaleExtensionRemover`, `CanvasFacade`) against
the sandbox. **It temporarily moves the test assignments' deadlines 10 days
later**, so it refuses to run against a production Canvas. For each of the three
assignment types it verifies:

- **REPRO** — before a sync, Canvas still gives a student their old extension
  date, even though the class deadline is now later. It reads the date Canvas
  actually applies to the student from the submission's `cached_due_date`.
- **SOLO** — after a sync, an override with one student is deleted, and Canvas
  gives that student the class deadline.
- **SHARED** — two students on a shared override both come off it, and neither
  is put back when the other is removed.
- **BYSTANDER** — a third student on that override, whose date doesn't match a
  request Flextensions approved, keeps the override and its dates.
- **LATER** — an extension still later than the new deadline is left in place.

It also checks the counts recorded for the course page (**TOTALS**), and that
syncing again changes nothing in Canvas (**RESYNC**).

The script restores the deadlines and removes its overrides when it finishes,
even after a failure. If it is killed partway through, run it again to clear the
overrides, and run `setup_test_course.rb` to reset the deadlines.

If Canvas recalculates due dates slowly and **SOLO** fails only on its date, try
a longer wait with `SETTLE_SECONDS=60`.
