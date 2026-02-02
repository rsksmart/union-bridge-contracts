#!/bin/bash
set -e

# Script to verify all contracts on alphanet
# Usage: ./verify-alphanet.sh <verifier> [broadcast-file]
#   verifier: "blockscout" or "rsk-explorer" (required)
#   broadcast-file: optional path to broadcast file

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../../.."

# set up environment variables
source .env

# Set network-specific variables
export NETWORK=alphanet
export CHAIN_ID=31
export RSK_EXPLORER_API=$RSK_EXPLORER_ALPHANET_API
export RSK_EXPLORER_URL=$RSK_EXPLORER_ALPHANET_URL

# Call the common verification script
"$CURRENT_PATH/verify-common.sh" "$@"
