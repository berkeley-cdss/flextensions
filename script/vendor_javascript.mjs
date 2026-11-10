// Copies the DataTables ES module builds out of node_modules into
// vendor/javascript, where the importmap pins in config/importmap.rb resolve
// them. Run with `npm run vendor:js` after bumping a datatables.net-* version
// in package.json, and commit the result.
//
// These files would normally be fetched by `bin/importmap pin <pkg> --download`,
// which pulls a jspm.io build of the same package. Sourcing them from the npm
// tarball instead keeps the vendored JavaScript and the CSS that
// app/assets/stylesheets/application.scss imports on exactly the version
// pinned in package.json, rather than two version numbers that have to be kept
// in step by hand.
//
// The published .min.mjs files import their siblings by bare specifier
// ("datatables.net", "datatables.net-bs5", ...), which is precisely what the
// importmap pins, so they need no rewriting.

import { copyFile, mkdir } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const vendor = resolve(root, 'vendor/javascript')

// source in node_modules -> name in vendor/javascript. The target names are
// the ones importmap-rails generates, so config/importmap.rb needs no `to:`
// beyond what it already has.
const FILES = {
  'datatables.net/js/dataTables.min.mjs': 'datatables.net.js',
  'datatables.net-bs5/js/dataTables.bootstrap5.min.mjs': 'datatables.net-bs5.js',
  'datatables.net-responsive/js/dataTables.responsive.min.mjs': 'datatables.net-responsive.js',
  'datatables.net-responsive-bs5/js/responsive.bootstrap5.min.mjs': 'datatables.net-responsive-bs5.js',
  'datatables.net-buttons/js/dataTables.buttons.min.mjs': 'datatables.net-buttons.js',
  'datatables.net-buttons-bs5/js/buttons.bootstrap5.min.mjs': 'datatables.net-buttons-bs5.js',
  'datatables.net-buttons/js/buttons.html5.min.mjs': 'datatables.net-buttons--js--buttons.html5.min.js.js',
  'datatables.net-buttons/js/buttons.print.min.mjs': 'datatables.net-buttons--js--buttons.print.min.js.js',
  'datatables.net-buttons/js/buttons.colVis.min.mjs': 'datatables.net-buttons--js--buttons.colVis.min.js.js'
}

await mkdir(vendor, { recursive: true })

for (const [source, target] of Object.entries(FILES)) {
  await copyFile(resolve(root, 'node_modules', source), resolve(vendor, target))
  console.log(`vendored ${target}`)
}
