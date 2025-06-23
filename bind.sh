#!/bin/sh
set -eux
# we go to the root of the project to avoid relative path issues
current_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$current_path";

forge bind \
    --module \
    --select "^(PegManager|BitcoinManager|CommitteeRegistry|SignatureManager|StreamManager)$" \
    --overwrite \
    --bindings-path ./crate/src/bindings
#    --alloy-version v0.14.0 \
# --crate-name union-bridge-contracts-bindings \
#    --crate-version 0.0.1-alpha.1 \
#
