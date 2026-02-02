#!/bin/bash
set -e

# Script to verify all contracts on testnet
# Usage: ./verify-testnet.sh <verifier> [broadcast-file]
#   verifier: "blockscout" or "rsk-explorer" (required)
#   broadcast-file: optional path to broadcast file

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../../.."

# set up environment variables
source .env

# Set network-specific variables
export NETWORK=testnet
export CHAIN_ID=31
export BLOCKSCOUT_API=$BLOCKSCOUT_TESTNET_API
export RSK_EXPLORER_API=$RSK_EXPLORER_TESTNET_API
export RSK_EXPLORER_URL=$RSK_EXPLORER_TESTNET_URL

# Call the common verification script
"$CURRENT_PATH/verify-common.sh" "$@"
