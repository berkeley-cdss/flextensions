---
title: Canvas Dates API (internal notes)
permalink: /canvas-dates-api/
---

# Canvas Assignment Dates & Overrides — Developer Notes

Internal reference for how Flextensions reads the **base ("Everyone") due
date** of a Canvas assignment and how it reads/writes **assignment overrides**
(the per-student/section extensions we provision).

It exists because the obvious-looking ways to get the base date are subtly
wrong for assignments with many overrides, and we kept adding machinery
(`include[]=all_dates`, the `/date_details` call) that turned out not to help.
The goal here is to write down what each Canvas parameter actually does — with
citations — so we stop re-litigating it.

> Citations point at `instructure/canvas-lms@master`. Behaviour is stable across
> recent Canvas versions but line numbers drift; search the file for the quoted
> symbol if a link has moved.

## TL;DR / decisions

- **To get the base date, request the assignment (list or single) with
  `override_assignment_dates=false` and read the top-level `due_at` /
  `unlock_at` / `lock_at`.** Canvas guarantees these are the assignment's own
  ("Everyone") dates, for *any* number of overrides. **This is the only thing we
  need for the base date — we read the top-level dates and request neither
  `all_dates` nor `overrides` on the assignment list.**
- **`include[]=all_dates` is not needed and we no longer request it.** It's a
  compact, *truncated* date summary (`[]` once an assignment has **≥ 25** dates,
  `ALL_DATES_LIMIT`); the top-level dates above are simpler and not truncated.
- **`include[]=overrides` is unrelated to the base date.** It returns the full
  list of override *records* (not a base date, not capped by the 25 limit). It
  is also unnecessary on the bulk list — sync only stores dates — and we fetch
  overrides directly from the overrides endpoint when provisioning. See
  [all_dates vs overrides](#all_dates-vs-overrides).
- **`/date_details` (Learning Object Dates) does not help us.** It has **no
  `base`/`base_date` field**; its top-level `due_at` is the same base date you
  already get from `override_assignment_dates=false`. We removed our use of it.
- **Yes, we still call the single-assignment endpoint** — on demand, to read a
  base date when provisioning an extension (`get_base_dates`). The bulk list is
  for syncing the assignment table; the single call is for "what's the base
  date *right now* for this one assignment."

## The parameters, precisely

### `override_assignment_dates` (default `true`)

> `@argument override_assignment_dates [Boolean]` — "Apply assignment overrides
> for each assignment, defaults to true."

```ruby
override_param = params[:override_assignment_dates] || true
override_dates = value_to_boolean(override_param)
# ...
assignment = assignment.overridden_for(user) if opts[:override_dates] && !assignment.new_record?
```

- **`true` (default):** the top-level `due_at`/`unlock_at`/`lock_at` are run
  through `overridden_for(user)` — i.e. the dates *as the calling user sees
  them*. For a user with an override that's the override's date; for a user with
  no override it's usually the base date, **but** for assignments that are
  `only_visible_to_overrides` it can be `nil`, and if the calling (staff) user
  happens to be inside a section/group override it's that override's date. This
  is the trap: the "assignment due date" you read back is user-relative.
- **`false`:** no `overridden_for` is applied; the top-level dates are the
  assignment record's own base dates. **This is what we want** and it is
  independent of override count.

Source: [`app/controllers/assignments_api_controller.rb`](https://github.com/instructure/canvas-lms/blob/master/app/controllers/assignments_api_controller.rb)
(`override_assignment_dates` argument and `override_dates`),
[`lib/api/v1/assignment.rb`](https://github.com/instructure/canvas-lms/blob/master/lib/api/v1/assignment.rb)
(`assignment.overridden_for(user)`).

### `include[]=all_dates` and the 25-date limit

> We **do not** request `all_dates` anymore (the top-level dates from
> `override_assignment_dates=false` are enough). This section is kept as the
> reference for *why* `all_dates` can't be trusted as a base-date source.

With `include[]=all_dates` the response carries an array of `AssignmentDate`
objects — one per override, plus a `base: true` entry **iff** the assignment has
an "Everyone"/"Everyone else" date. The exact serializer (pinned):

```ruby
ALL_DATES_LIMIT = 25
# ...
if opts[:include_all_dates]
  overrides = assignment.has_sub_assignments? ? assignment.sub_assignment_overrides : assignment.assignment_overrides
  if overrides
    override_count = overrides.loaded? ? overrides.count(&:active?) : overrides.active.count

    if assignment.has_sub_assignments? && override_count < ALL_DATES_LIMIT
      hash["all_dates"] = []
      assignment.sub_assignments.each do |sub_assignment|
        hash["all_dates"].concat(sub_assignment.dates_hash_visible_to(user))
      end
    elsif override_count < ALL_DATES_LIMIT
      hash["all_dates"] = assignment.dates_hash_visible_to(user)
    else
      hash["all_dates_count"] = override_count
      hash["all_dates"] = []   # <-- empty array, NOT omitted
    end
  end
end
```

Read this carefully, because the obvious checks are wrong:

1. **`all_dates` is set in *every* branch** (it is always an array, never
   omitted, whenever `include[]=all_dates` is requested). So "is the key
   present / is it truthy" tells you nothing — `[]` is **truthy in Ruby**, so
   `if data['all_dates']` is true even when empty, and
   `data['all_dates'].find { base }` then silently returns `nil`.
2. **`all_dates_count` is added *only* in the truncated (`else`) branch** — when
   `override_count >= ALL_DATES_LIMIT` (≥ 25). It is therefore the **definitive
   truncation signal**, and its value is the real override count.
3. Past the limit there is **no `base: true` entry** to find.

**So detect truncation explicitly: treat the list as untrusted if
`all_dates_count` is present, and only read the base entry when `all_dates` is a
non-empty array.** Don't rely on truthiness, and don't rely on length alone —
check both the `all_dates_count` flag and the length. When truncated, get the
base date from the top level (`override_assignment_dates=false`).

Source (pinned):
[`lib/api/v1/assignment.rb@9e60178`](https://github.com/instructure/canvas-lms/blob/9e60178649c2bc13684bbdf2019010aa9f3b21a3/lib/api/v1/assignment.rb#L391)
(`ALL_DATES_LIMIT`, `all_dates` / `all_dates_count`).

### `include[]=overrides`

Returns an array of full `AssignmentOverride` records — `id`, `title`,
`assignment_id`, the target (`student_ids`/`course_section_id`/`group_id`/…),
and the overridden `due_at`/`unlock_at`/`lock_at`. It is gated on
manage-assignments permission (the caller only sets `include_overrides` when the
user can manage). It is **not** subject to the 25-date `all_dates` truncation:

```ruby
if opts[:overrides].present?
  hash["overrides"] = assignment_overrides_json(opts[:overrides], user)
elsif opts[:include_overrides]
  hash["overrides"] = assignment_overrides_json(assignment.assignment_overrides.select(&:active?), user)
end
```

We don't request it on the bulk list (sync only stores dates). When provisioning
we read overrides from the dedicated, paginated overrides endpoint instead — see
[Reading overrides](#reading-overrides-for-provisioning).

Source (pinned):
[`lib/api/v1/assignment.rb@9e60178`](https://github.com/instructure/canvas-lms/blob/9e60178649c2bc13684bbdf2019010aa9f3b21a3/lib/api/v1/assignment.rb#L391),
[`lib/api/v1/assignment_override.rb`](https://github.com/instructure/canvas-lms/blob/9e60178649c2bc13684bbdf2019010aa9f3b21a3/lib/api/v1/assignment_override.rb).

### `all_dates` vs `overrides`

They look similar (both list per-override dates) but answer different questions,
and only one carries the base date:

| | `include[]=all_dates` | `include[]=overrides` |
| --- | --- | --- |
| What it is | Date *summaries* (`AssignmentDate`: `id`, `base`, `title`, `due_at`, `unlock_at`, `lock_at`) | Full override *records* (`AssignmentOverride`: target ids, title, overridden dates) |
| Includes the base ("Everyone") date? | **Yes** — a synthetic `base: true` entry, when one exists | **No** — overrides only; the base date stays in the top-level `due_at` |
| Truncated at 25? | **Yes** → `[]` + `all_dates_count` | **No** — all active overrides |
| Permission | Visibility-filtered; no manage permission needed | Requires manage-assignments |
| Good for | A quick "what dates does this assignment have" pill list (small assignments) | Enumerating the actual override objects (who/what each targets) |

So `overrides` being "complete" doesn't make `all_dates` redundant *in general* —
`overrides` never contains the base date. But **for our needs neither is
required**: the base date comes from the top-level `due_at`
(`override_assignment_dates=false`), and when we need the override objects we hit
the overrides endpoint directly.

### `/date_details` (Learning Object Dates) — and why we don't use it

`GET /api/v1/courses/:course_id/assignments/:id/date_details` returns a
`LearningObjectDates` object: top-level `id`, `due_at`, `lock_at`, `unlock_at`,
`only_visible_to_overrides`, `visible_to_everyone`, `graded`, a **paginated**
`overrides` list, plus blueprint/checkpoint fields.

- There is **no `base` or `base_date` key.** (An earlier version of our code
  claimed there was and sliced a non-existent field.)
- Its top-level `due_at`/`lock_at`/`unlock_at` are the asset's own base dates —
  the *same values* you get from the assignment endpoint with
  `override_assignment_dates=false`.

So `date_details` adds an extra round-trip and no information for our purpose.
We removed `get_assignment_date_details`/the date_details code path. (The
`url:GET|.../date_details` developer-key scope is currently unused; leave it in
`CANVAS_API_SCOPES` until it can be removed in coordination with the Canvas key,
since our list must match the key exactly.)

Source: [`app/controllers/learning_object_dates_controller.rb`](https://github.com/instructure/canvas-lms/blob/master/app/controllers/learning_object_dates_controller.rb)
and [`lib/api/v1/learning_object_dates.rb`](https://github.com/instructure/canvas-lms/blob/master/lib/api/v1/learning_object_dates.rb);
REST docs: [Learning Object Dates](https://canvas.instructure.com/doc/api/learning_object_dates.html),
[Assignments](https://canvas.instructure.com/doc/api/assignments.html).

## The bug this clears up

The base date can be read **incorrectly** when you trust either the default
`override_assignment_dates` or the `all_dates` base entry. Concretely, the base
date came back wrong / blank for assignments where:

- there are **≥ 25 dates**, so `all_dates` is empty and any "find the base
  entry" logic yields `nil`; and/or
- `override_assignment_dates` is left at its default `true`, so the top-level
  date is `overridden_for(sync_user)` — user-relative, and `nil` for
  `only_visible_to_overrides` assignments.

The remedy is a single rule: **always pass `override_assignment_dates=false` and
read the top-level dates.** That is correct at any override count and needs no
`all_dates` parsing and no `/date_details` call.

## How Flextensions does it now

All of this lives in `app/facades/canvas_facade.rb`.

### Reading the base date

- `get_assignments(course_id)` — bulk list for sync. Sends
  `override_assignment_dates=false`, `per_page=100`. No `include[]` — the
  top-level dates are all we need.
- `get_all_assignments(course_id)` — depaginates the above and builds
  `Lmss::Canvas::Assignment` POROs straight from the top-level fields. No
  `all_dates`/`base_date` parsing.
- `get_assignment(course_id, assignment_id)` — single assignment with
  `override_assignment_dates=false`.
- `get_base_dates(course_id, assignment_id)` — calls `get_assignment` and
  returns `{ 'due_at', 'unlock_at', 'lock_at' }` from the top level. Used when
  provisioning an extension (to record the original due date and to title the
  override by extension length).

`Lmss::Canvas::Assignment#extract_date_field` just reads the top-level field —
which, thanks to `override_assignment_dates=false`, is the base date.

### Reading overrides for provisioning

- `get_assignment_overrides` requests `per_page=100`;
  `get_all_assignment_overrides` depaginates it. **Always depaginate** when
  searching for a student's override — an assignment can have far more than one
  page, and missing an existing override orphans it.
- Overrides are titled `"N day(s) extension"` so students with the same-length
  extension share one override (fewer overrides ⇒ less chance of hitting the
  25-date limit in the first place). See `provision_extension` /
  `extension_override_title`.

### Writing overrides

`create_assignment_override` and `update_assignment_override` both nest the body
under `assignment_override:` — Canvas silently ignores un-nested params on the
update (PUT) endpoint, which previously made title/date updates no-ops.

## Quick reference

| Need | Call | Key params |
| --- | --- | --- |
| Base date, one assignment | `GET assignments/:id` | `override_assignment_dates=false` |
| Base date, all assignments | `GET assignments` | `override_assignment_dates=false`, `per_page=100` |
| All overrides for an assignment | `GET assignments/:id/overrides` | `per_page=100` + depaginate |
| Create / update an override | `POST` / `PUT .../overrides[/:id]` | body under `assignment_override:` |
| ~~Base date via date_details~~ | — | not needed; no base field |

## Sources

- Canvas REST API — [Assignments](https://canvas.instructure.com/doc/api/assignments.html)
  (`override_assignment_dates`, `include[]` = `all_dates` / `overrides`, the
  `AssignmentDate` object and its `base` flag).
- Canvas REST API — [Learning Object Dates / date_details](https://canvas.instructure.com/doc/api/learning_object_dates.html).
- `instructure/canvas-lms` —
  [`assignments_api_controller.rb`](https://github.com/instructure/canvas-lms/blob/master/app/controllers/assignments_api_controller.rb),
  [`lib/api/v1/assignment.rb`](https://github.com/instructure/canvas-lms/blob/master/lib/api/v1/assignment.rb)
  (`ALL_DATES_LIMIT = 25`, `overridden_for`),
  [`learning_object_dates_controller.rb`](https://github.com/instructure/canvas-lms/blob/master/app/controllers/learning_object_dates_controller.rb),
  [`lib/api/v1/learning_object_dates.rb`](https://github.com/instructure/canvas-lms/blob/master/lib/api/v1/learning_object_dates.rb).
