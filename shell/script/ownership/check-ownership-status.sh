#!/bin/bash
set -e

# Usage: check-ownership-status.sh <network>
# network: testnet, mainnet, alphanet, local, or regtest

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# set up environment variables
source .env

# Source common functions
source "$CURRENT_PATH/ownership-common.sh"

# Get network from argument
NETWORK="${1}"

# Validate network is set
if [[ -z "$NETWORK" ]]; then
    echo "Error: Network must be provided as argument" >&2
    echo "Usage: $0 <network>" >&2
    echo "  network: testnet, mainnet, alphanet, local, or regtest" >&2
    exit 1
fi

# Set up network-specific variables
if ! setup_network "$NETWORK"; then
    exit 1
fi

echo "================ CHECK OWNERSHIP STATUS ($NETWORK) ================"
echo "Network: $NETWORK"
echo "RPC: $RPC"
echo ""

# Build forge script command (view function, no broadcast needed)
FORGE_CMD="forge script \
    script/owner/OwnershipManager.s.sol:OwnershipManager \
    --sig \"checkOwnershipStatus()\" \
    --rpc-url $RPC \
    --legacy"

# Execute script
eval $FORGE_CMD

EXIT_CODE=$?
exit $EXIT_CODE
