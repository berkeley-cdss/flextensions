# Be sure to restart your server when you modify this file.

# dartsass-rails shells out to the Dart Sass CLI, so its configuration is a
# list of command-line flags rather than a Ruby options hash.
#
# --quiet-deps drops deprecations raised inside gem-provided stylesheets
# (Bootstrap, Font Awesome); we can't fix those, and Bootstrap 5.3 alone emits
# thousands of lines of them per build. --silence-deprecation=import covers the
# `@import` lines in application.scss itself, which --quiet-deps does not reach.
#
# Drop the silencing once Bootstrap 6 ships and the `@import`s can become
# `@use`.
Rails.application.config.dartsass.build_options += [
  '--quiet-deps',
  '--silence-deprecation=import'
]

# The gem's default is --style=compressed --no-source-map for every
# environment. Sprockets only compressed outside development, so keep the
# built CSS readable and mapped back to the .scss sources while developing.
if Rails.env.development?
  Rails.application.config.dartsass.build_options -= [ '--style=compressed', '--no-source-map' ]
  Rails.application.config.dartsass.build_options += [ '--style=expanded', '--embed-sources' ]
end

# DataTables ships its Bootstrap 5 theme as plain CSS on npm, so application.scss
# imports it out of node_modules. Nothing puts those directories on the Sass
# load path for us.
Rails.application.config.dartsass.build_options += [
  '--load-path', Rails.root.join('node_modules/datatables.net-bs5/css').to_s,
  '--load-path', Rails.root.join('node_modules/datatables.net-responsive-bs5/css').to_s
]

# The bootstrap and font-awesome-sass gems put their Sass sources on the asset
# load path so application.scss can @import them. Propshaft has one load path
# and serves everything on it, so leaving them there digests ~110 .scss
# partials into public/assets. dartsass-rails builds its --load-path list from
# config.assets.paths, so hand Dart Sass the directories directly and then take
# them off Propshaft's path. (font-awesome-sass' assets/fonts directory has to
# stay — that one holds the webfonts the built CSS points at.)
sass_gem_paths = %w[bootstrap font-awesome-sass].filter_map do |name|
  spec = Gem.loaded_specs[name]
  File.join(spec.gem_dir, 'assets', 'stylesheets') if spec
end

Rails.application.config.dartsass.build_options +=
  sass_gem_paths.flat_map { |path| [ '--load-path', path ] }
Rails.application.config.assets.excluded_paths += sass_gem_paths
