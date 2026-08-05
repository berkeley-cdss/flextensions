# Be sure to restart your server when you modify this file.

# Propshaft serves everything it finds on the load path and digests it by
# content, so there is no precompile list to maintain — that was a Sprockets
# concept, as was the manifest.js this app used to carry.
#
# Rails adds every app/assets/* subdirectory to the load path automatically, so
# app/assets/builds (where Dart Sass writes application.css) needs no config.

# The Sass sources are inputs to the build, not assets to serve; excluding them
# keeps unbuilt .scss out of public/assets.
Rails.application.config.assets.excluded_paths << Rails.root.join('app/assets/stylesheets')
