import { Controller } from "@hotwired/stimulus"

// Resets one email template's subject/body fields to their defaults on the
// client. Attach to each template card (approval, denial) so a reset only
// touches that card. Nothing is persisted until the user saves the form.
export default class extends Controller {
  static targets = ["subject", "body"]
  static values = { defaultSubject: String, defaultBody: String }

  reset() {
    this.subjectTarget.value = this.defaultSubjectValue
    this.bodyTarget.value = this.defaultBodyValue
  }
}
