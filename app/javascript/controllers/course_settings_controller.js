import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["emailField", "gradescopeField", "pensieveField", "slackWebhookField", "pendingNotificationEmail"];

  connect() {
    this.toggleEmailFields();
    this.toggleSlackWebhookField();
    this.toggleGradescopeFields();
    this.togglePensieveFields();
    this.togglePendingNotificationEmail();

    const gradescopeToggle = document.getElementById('enable-gradescope');
    if (gradescopeToggle) {
      gradescopeToggle.addEventListener('change', this.toggleGradescopeFields.bind(this));
    }

    const pensieveToggle = document.getElementById('enable-pensieve');
    if (pensieveToggle) {
      pensieveToggle.addEventListener('change', this.togglePensieveFields.bind(this));
    }

    const emailToggle = document.getElementById('enable-email');
    if (emailToggle) {
      emailToggle.addEventListener('change', this.toggleEmailFields.bind(this));
    }

    const slackToggle = document.getElementById('enable-slack');
    if (slackToggle) {
      slackToggle.addEventListener('change', this.toggleSlackWebhookField.bind(this));
    }
  }

  toggleGradescopeFields() {
    const gradescopeToggle = document.getElementById('enable-gradescope');
    const gradescopeCourseUrlField = document.getElementById('gradescope-course-url');

    if (gradescopeToggle && gradescopeCourseUrlField) {
      const isEnabled = gradescopeToggle.checked;
      gradescopeCourseUrlField.disabled = !isEnabled;
    }
  }

  togglePensieveFields() {
    const pensieveToggle = document.getElementById('enable-pensieve');
    const pensieveCourseUrlField = document.getElementById('pensieve-course-url');

    if (pensieveToggle && pensieveCourseUrlField) {
      pensieveCourseUrlField.disabled = !pensieveToggle.checked;
    }
  }

  toggleEmailFields() {
    const emailToggle = document.getElementById('enable-email');
    const replyEmailField = document.getElementById('reply-email');

    if (emailToggle && replyEmailField) {
      const isEnabled = emailToggle.checked;
      replyEmailField.disabled = !isEnabled;
    }
  }

  toggleSlackWebhookField() {
    const slackToggle = document.getElementById('enable-slack');
    const slackWebhookField = document.getElementById('slack-webhook');

    if (slackToggle && slackWebhookField) {
      slackWebhookField.disabled = !slackToggle.checked;
    }
  }

  togglePendingNotificationEmail() {
    const frequencySelect = document.getElementById('pending-notification-frequency');
    const emailField = document.getElementById('pending-notification-email');

    if (frequencySelect && emailField) {
      emailField.disabled = !frequencySelect.value;
    }
  }
}
