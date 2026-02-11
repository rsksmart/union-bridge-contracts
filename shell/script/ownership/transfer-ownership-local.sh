#!/bin/bash
set -e

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# set up environment variables
source .env

# Set network-specific variables
export NETWORK=local
export RPC=$LOCAL_RPC
export CHAIN_ID=31337

# Get new owner address from argument
NEW_OWNER_ADDRESS="${1}"

if [[ -z "$NEW_OWNER_ADDRESS" ]]; then
    echo "Error: New owner address must be provided as argument" >&2
    echo "Usage: $0 <newOwnerAddress>" >&2
    exit 1
fi

# Call the common transfer ownership script
"$CURRENT_PATH/transfer-ownership-common.sh" "$NEW_OWNER_ADDRESS"
