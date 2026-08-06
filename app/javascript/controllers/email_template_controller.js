import { Controller } from "@hotwired/stimulus"

// Resets the email subject/body fields to their defaults on the client.
// Nothing is persisted until the user saves the form.
export default class extends Controller {
  static targets = ["subject", "body"]
  static values = { defaultSubject: String, defaultBody: String }

  reset() {
    this.subjectTarget.value = this.defaultSubjectValue
    this.bodyTarget.value = this.defaultBodyValue
  }
}
