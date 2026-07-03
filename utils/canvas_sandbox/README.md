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

It then replays the production failure mode (**NOCREDS**): the course's
first-enrolled staff member has no Canvas credentials — e.g. a TA synced from
the Canvas roster who never logged into Flextensions — and asserts
auto-approval still succeeds by using another credentialed staff user.

The script cleans up the Canvas overrides it created; pass `KEEP_OVERRIDES=1`
to leave them in place for manual inspection.
