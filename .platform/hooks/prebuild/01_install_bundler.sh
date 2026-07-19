#!/bin/bash
dnf remove libpq-devel -y
dnf install postgresql17-devel -y
# Keep in sync with BUNDLED WITH in Gemfile.lock
gem install bundler -v 4.0.16
