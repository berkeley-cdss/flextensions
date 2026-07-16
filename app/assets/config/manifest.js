//= link_tree ../images
// Only the manifest stylesheet is compiled standalone. Do NOT link the whole
// directory: Sprockets would also compile the _*.scss partials on their own,
// where the variables from application.scss are not defined.
//= link application.css
//= link_tree ../../javascript .js
//= link_tree ../../../vendor/javascript .js

//= link stimulus-loading.js
