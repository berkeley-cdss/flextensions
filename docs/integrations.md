---
title: Integrating Flextensions
permalink: /integrations/
---

# Integrating Flextensions with Your Tools

Flextensions, of course, already integrates with Canvas. However, you may want to connect it with other tools you use to manage your course.

## Slack

Flextensions can be integrated with Slack to provide real-time notifications and updates. This allows instructors and students to stay informed about important events, such as assignment due dates and extension requests.

### Setting Up Slack Integration

Flextensions uses a Slack Webhook to send notifications to your Slack workspace, which are sent whenever there is a new extension request or an update to an existing request, including showing whether they are auto-approved.

**In Slack**

1. Go to your Slack workspace and navigate to **Apps**.
2. Search for and select **Incoming WebHooks**.
3. Click **Add to Slack**.
4. Choose the channel where you want to receive notifications and click **Add Incoming WebHooks integration**.
5. Copy the Webhook URL provided.

**In Flextensions**

1. Navigate to the **Settings** tab.
2. Click on **Slack Integration**.
3. Paste the Webhook URL into the provided field.
4. Click **Save** to enable Slack notifications.

## Pensive

Pensive uses an application-level integration account rather than each
instructor's credentials. The Pensive account must be invited to every Pensive
class Flextensions will manage. Generate an API token from that account's
profile, then configure:

```dotenv
PENSIEVE_EMAIL=service-account@example.edu
PENSIEVE_API_TOKEN=...
PENSIEVE_ASSIGNMENTS_PATH=/path/provided-by-pensive
```

The `PENSIEVE_*` spelling is retained for compatibility with Pensive's legacy
API and the original extensions integration. `PENSIEVE_API_URL` can override
the default API host (`https://api.pensieve.co`) when needed.

Link each Flextensions course to LMS id `3`, using the Pensive class id as the
`CourseToLms.external_course_id`. The existing
`POST /api/v1/courses/:course_id/lmss` API can create this link; send `lms_id`
and `external_course_id` in the request body.

### Assignment sync contract

The extracted legacy integration only provides extension posting; it does not
provide an assignment-list endpoint. Flextensions calls the configured
`PENSIEVE_ASSIGNMENTS_PATH` with a bearer token and a `class_id` query
parameter. Pensive must provide that endpoint with this response shape:

```json
{
  "success": true,
  "assignments": [
    {
      "assignment_url": "https://www.pensieve.co/teacher/classes/example/my-assignments/online/assignment-id/extensions",
      "name": "Homework 1",
      "release_date": "2026-08-01T00:00:00Z",
      "due_date": "2026-08-08T07:00:00Z",
      "hard_due_date": "2026-08-10T07:00:00Z"
    }
  ]
}
```

`assignment_url` and `name` are required. The date fields may be null. The full
assignment URL is stored as the external assignment id because Pensive's
extension API uses that URL, rather than a standalone assignment id, to select
the assignment.

### Posting extensions

Flextensions posts approved requests to
`/api/b2s/v1/external-client/grant-extension` with the assignment URL, student
email, and requested number of whole extension days. A successful response must
contain `{"success": true}`. If Pensive supplies an `extension_id`, it is saved
on the request; the legacy response omits it, so that field otherwise remains
blank.
