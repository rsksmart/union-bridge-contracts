#!/bin/bash
set -e

# Script to verify all contracts on mainnet
# Usage: ./verify-mainnet.sh <verifier> [broadcast-file]
#   verifier: "blockscout" or "rsk-explorer" (required)
#   broadcast-file: optional path to broadcast file

# WARNING: This script verifies contracts on RSK MAINNET
# Double-check all parameters before proceeding

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../../.."

# set up environment variables
source .env

# Set network-specific variables
export NETWORK=mainnet
export CHAIN_ID=30
export BLOCKSCOUT_API=$BLOCKSCOUT_MAINNET_API
export RSK_EXPLORER_API=$RSK_EXPLORER_MAINNET_API
export RSK_EXPLORER_URL=$RSK_EXPLORER_MAINNET_URL

# Call the common verification script
"$CURRENT_PATH/verify-common.sh" "$@"
