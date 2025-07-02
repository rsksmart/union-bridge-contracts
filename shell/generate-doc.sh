#!/bin/sh
# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$CURRENT_PATH/..";
# https://getfoundry.sh/forge/reference/forge-doc/
forge doc --build
