import { Controller } from "@hotwired/stimulus"

// Warns about unsaved edits on a settings form. The first change shows a toast
// and arms a beforeunload prompt; saving (form submit) clears both so leaving
// the page after a save is silent.
export default class extends Controller {
  static targets = ["toast"]

  connect() {
    this.dirty = false
    this.beforeUnloadHandler = this.warnBeforeUnload.bind(this)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.beforeUnloadHandler)
  }

  markDirty() {
    if (this.dirty) return
    this.dirty = true
    window.addEventListener("beforeunload", this.beforeUnloadHandler)
    this.toast()?.show()
  }

  // Called on form submit: the change is being persisted, so drop the warnings.
  save() {
    this.dirty = false
    window.removeEventListener("beforeunload", this.beforeUnloadHandler)
    this.toast()?.hide()
  }

  warnBeforeUnload(event) {
    event.preventDefault()
    // Browsers show their own generic message; the toast carries our wording.
    event.returnValue = "You have unsaved changes to your course. Please select save if you wish to keep your changes."
    return event.returnValue
  }

  toast() {
    if (!this.hasToastTarget || !window.bootstrap) return null
    return window.bootstrap.Toast.getOrCreateInstance(this.toastTarget, { autohide: false })
  }
}
