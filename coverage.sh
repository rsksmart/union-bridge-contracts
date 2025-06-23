#!/bin/sh
set -eux
bash shell/clean-build.sh
# https://getfoundry.sh/forge/reference/forge-coverage.html
forge coverage --report lcov --report summary --no-match-coverage "(script|test)"