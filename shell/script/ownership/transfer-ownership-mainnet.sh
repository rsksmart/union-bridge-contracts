#!/bin/bash
set -e

# WARNING: This script transfers ownership on RSK MAINNET
# Double-check all parameters before proceeding

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# set up environment variables
source .env

# Set network-specific variables
export NETWORK=mainnet
export RPC=$RSK_MAINNET_RPC
export CHAIN_ID=30

# Get new owner address from argument
NEW_OWNER_ADDRESS="${1}"

if [[ -z "$NEW_OWNER_ADDRESS" ]]; then
    echo "Error: New owner address must be provided as argument" >&2
    echo "Usage: $0 <newOwnerAddress>" >&2
    exit 1
fi

# Call the common transfer ownership script
"$CURRENT_PATH/transfer-ownership-common.sh" "$NEW_OWNER_ADDRESS"
