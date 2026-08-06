// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

import "color-modes"
import "@hotwired/stimulus"
import "@hotwired/stimulus-loading"
// Popper must execute before Bootstrap: Bootstrap's UMD build captures
// globalThis.Popper at load time, and controllers (imported below) pull in
// Bootstrap, so Popper has to be set up first or tooltips/popovers fail with
// "createPopper is not a function".
import "@popperjs/core"
import "bootstrap"
import "controllers"
import "@rails/ujs"
import "rails-ujs-override"