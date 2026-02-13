#!/bin/bash
set -e

# Usage: transfer-ownership.sh <network> <newOwnerAddress>
# network: testnet, mainnet, alphanet, local, or regtest
# newOwnerAddress: The address that will become the new owner

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# set up environment variables
source .env

# Source common functions
source "$CURRENT_PATH/ownership-common.sh"

# Get network from argument
NETWORK="${1}"

# Validate network argument
if ! validate_network_argument "$NETWORK"; then
    echo "Usage: $0 <network> <newOwnerAddress>" >&2
    exit 1
fi

# Set up network-specific variables
if ! setup_network "$NETWORK"; then
    exit 1
fi

# Get new owner address from argument
NEW_OWNER_ADDRESS="${2}"

# Validate new owner address is set
if [[ -z "$NEW_OWNER_ADDRESS" ]]; then
    echo "Error: New owner address must be provided as second argument" >&2
    echo "Usage: $0 <network> <newOwnerAddress>" >&2
    exit 1
fi

# Validate new owner address is a valid address format (basic check)
if [[ ! "$NEW_OWNER_ADDRESS" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    echo "Error: Invalid address format: $NEW_OWNER_ADDRESS" >&2
    exit 1
fi

echo "================ TRANSFER OWNERSHIP ($NETWORK) ================"
echo "Network: $NETWORK"
echo "RPC: $RPC"
echo "New Owner: $NEW_OWNER_ADDRESS"
echo ""

# Mainnet warning
if [[ "$NETWORK" == "mainnet" ]]; then
    echo "WARNING: You are about to transfer ownership on RSK MAINNET"
    echo "Type 'yes' to continue, or anything else to cancel:"
    read -r confirmation
    if [[ "$confirmation" != "yes" ]]; then
        echo "Operation cancelled."
        exit 1
    fi
fi

# Build forge script command
FORGE_CMD="forge script \
    script/owner/OwnershipManager.s.sol:OwnershipManager \
    --sig \"transferAllOwnership(address)\" $NEW_OWNER_ADDRESS \
    --rpc-url $RPC \
    --broadcast \
    --interactives 1 \
    --legacy"

# Add gas-price from .env (if set)
if [[ -n "$GAS_PRICE_IN_WEIS" ]]; then
    FORGE_CMD="$FORGE_CMD --gas-price $GAS_PRICE_IN_WEIS"
fi

# Execute script
eval $FORGE_CMD

EXIT_CODE=$?
exit $EXIT_CODE
