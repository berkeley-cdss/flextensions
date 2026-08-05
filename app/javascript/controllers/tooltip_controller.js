import { Controller } from "@hotwired/stimulus"

// Initializes a Bootstrap tooltip on its element (Bootstrap does not auto-init
// tooltips). Useful on a wrapper around a disabled control, which can't fire
// its own hover events.
export default class extends Controller {
  connect() {
    if (window.bootstrap) {
      this.tooltip = window.bootstrap.Tooltip.getOrCreateInstance(this.element)
    }
  }

  disconnect() {
    this.tooltip?.dispose()
  }
}
