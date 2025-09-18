#!/bin/bash
set -e
# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$CURRENT_PATH/..";
# https://getfoundry.sh/forge/reference/forge-bind
forge bind \
    --module \
    --select "^(PegManager|BitcoinManager|CommitteeRegistry|SignatureManager|StreamManager|MemberRegistry)$" \
    --overwrite \
    --bindings-path ./crate/src/bindings
