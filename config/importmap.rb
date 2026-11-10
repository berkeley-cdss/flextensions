# config/importmap.rb
# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

pin_all_from "app/javascript/controllers", under: "controllers"

pin "@rails/ujs", to: "https://ga.jspm.io/npm:@rails/ujs@7.0.4/lib/assets/compiled/rails-ujs.js"
pin "rails-ujs-override", to: "rails-ujs-override.js"

# Bootstrap and dependencies. The datatables.net-* files under
# vendor/javascript are copied out of node_modules by `npm run vendor:js`, so
# the versions below are the ones pinned in package.json -- keep them in step.
pin "bootstrap", to: "bootstrap.min.js", preload: true
pin "@popperjs/core", to: "popper.js", preload: true
pin "color-modes"
pin "datatables.net" # @3.1.2
pin "datatables.net-bs5" # @3.1.2
pin "datatables.net-responsive-bs5" # @4.1.1
pin "datatables.net-responsive" # @4.1.1
pin "datatables.net-buttons" # @4.1.2
pin "datatables.net-buttons-bs5" # @4.1.2
pin "datatables.net-buttons/js/buttons.html5.min.js", to: "datatables.net-buttons--js--buttons.html5.min.js.js" # @4.1.2
pin "datatables.net-buttons/js/buttons.print.min.js", to: "datatables.net-buttons--js--buttons.print.min.js.js" # @4.1.2
pin "datatables.net-buttons/js/buttons.colVis.min.js", to: "datatables.net-buttons--js--buttons.colVis.min.js.js" # @4.1.2
