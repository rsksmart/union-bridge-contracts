#!/bin/bash
set -e

# WARNING: This script deploys to RSK MAINNET
# Double-check all parameters before proceeding

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# set up environment variables
source .env

# Set network-specific variables
export NETWORK=mainnet
export RPC=$RSK_MAINNET_RPC
export RSK_EXPLORER_API=$RSK_EXPLORER_MAINNET_API
export RSK_EXPLORER_URL=$RSK_EXPLORER_MAINNET_URL
export BLOCKSCOUT_API=$BLOCKSCOUT_MAINNET_API
export CHAIN_ID=30

# Call the common deployment script
"$CURRENT_PATH/deploy-common.sh"
