#!/bin/bash
set -e

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# set up environment variables
source .env

# Set network-specific variables
export NETWORK=testnet
export RPC=$RSK_TESTNET_RPC
export RSK_EXPLORER_API=$RSK_EXPLORER_TESTNET_API
export RSK_EXPLORER_URL=$RSK_EXPLORER_TESTNET_URL
export BLOCKSCOUT_API=$BLOCKSCOUT_TESTNET_API
export CHAIN_ID=31

# Call the common deployment script
"$CURRENT_PATH/deploy-common.sh"
