// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

import "color-modes"
import "@hotwired/stimulus"
import "@hotwired/stimulus-loading"
import "controllers"
import "@rails/ujs"
import "rails-ujs-override"
import "@popperjs/core"
import "bootstrap"
import htmx from "htmx.org"

// Configure HTMX to send the Rails CSRF token with every request
document.addEventListener("htmx:configRequest", (event) => {
  const token = document.querySelector('meta[name="csrf-token"]')?.content
  if (token) {
    event.detail.headers["X-CSRF-Token"] = token
  }
})

// Handle HX-Trigger flash events dispatched by the server
document.addEventListener("htmx:afterRequest", (event) => {
  const triggerHeader = event.detail.xhr?.getResponseHeader("HX-Trigger")
  if (!triggerHeader) return
  try {
    const triggers = JSON.parse(triggerHeader)
    if (triggers.flash) {
      const { type, message } = triggers.flash
      window.dispatchEvent(new CustomEvent("flash", { detail: { type, message } }))
    }
  } catch {
    // non-JSON trigger header; ignore
  }
})

// Roll back checkbox state and show alert on network send errors.
// Note: HTTP response errors (non-2xx) are handled per-element via hx-on::htmx:response-error.
// This handler covers network-level failures (no HTTP response received) only.
document.addEventListener("htmx:sendError", (event) => {
  const elt = event.detail.elt
  if (elt && elt.type === "checkbox") {
    elt.checked = !elt.checked
  }
  window.dispatchEvent(new CustomEvent("flash", { detail: { type: "alert", message: "Network error. Please try again." } }))
})

window.htmx = htmx