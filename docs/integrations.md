---
title: Integrating Flextensions
permalink: /integrations/
---

# Integrating Flextensions with Your Tools

Flextensions, of course, already integrates with Canvas. However, you may want to connect it with other tools you use to manage your course.

## Pensieve

Flextensions can post approved extensions to [Pensieve](https://www.pensieve.co) through Pensieve's external-client API.

### Setting Up Pensieve Integration

1. Ask Pensieve for an external-client API token; the Flextensions deployment must have it configured as `PENSIEVE_API_TOKEN`.
2. Navigate to the **Course Details** page for your course.
3. Enable **Link Pensieve course** and enter your course's Pensieve URL.
4. Click **Save**.

When an extension request is approved for a Pensieve assignment, Flextensions grants the student the corresponding number of extra days on the assignment in Pensieve.

Note that Pensieve extensions are granted in whole days past the original deadline, and Pensieve does not have a separate late (hard) due date.

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
