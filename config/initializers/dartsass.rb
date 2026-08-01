# Be sure to restart your server when you modify this file.

# Configuration for dartsass-sprockets, which compiles app/assets/stylesheets
# with Dart Sass. It keeps sassc-rails' `config.sass` namespace, so the options
# below are the ones sassc-rails understood plus Dart Sass' deprecation
# controls.

# Don't report deprecations raised inside gem-provided stylesheets (Bootstrap,
# Font Awesome). We can't fix those, and Bootstrap 5.3 alone emits thousands of
# lines of them per compile.
Rails.application.config.sass.quiet_deps = true

# `quiet_deps` only covers files loaded from the load path, so the `@import`
# lines in application.scss itself still warn. Silence that one deprecation
# everywhere; every other deprecation in our own stylesheets stays visible.
#
# Drop this once Bootstrap 6 ships and the `@import`s can become `@use`.
Rails.application.config.sass.silence_deprecations = [ 'import' ]
