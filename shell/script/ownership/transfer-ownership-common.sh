#!/bin/bash
set -e

# Usage: transfer-ownership-common.sh <newOwner>
# newOwner: The address that will become the new owner
# Note: NETWORK and RPC should be exported by the calling script

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# Validate NETWORK is set (should be exported by calling script)
if [[ -z "$NETWORK" ]]; then
    echo "Error: NETWORK environment variable not set. This should be exported by the calling script." >&2
    exit 1
fi

# Validate RPC is set
if [[ -z "$RPC" ]]; then
    echo "Error: RPC URL not set for network '$NETWORK'" >&2
    exit 1
fi

# Get newOwner from argument
NEW_OWNER_ADDRESS="${1}"

# Validate newOwner is set
if [[ -z "$NEW_OWNER_ADDRESS" ]]; then
    echo "Error: New owner address not provided" >&2
    echo "Usage: $0 <newOwnerAddress>" >&2
    exit 1
fi

# Validate newOwner is a valid address format (basic check)
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
    script/TransferOwnership.s.sol:TransferOwnership \
    --sig \"transferAllOwnership(address)\" $NEW_OWNER_ADDRESS \
    --rpc-url $RPC \
    --broadcast \
    --legacy"

# Add gas-price from .env (if set)
if [[ -n "$GAS_PRICE_IN_WEIS" ]]; then
    FORGE_CMD="$FORGE_CMD --gas-price $GAS_PRICE_IN_WEIS"
fi

# Execute script
eval $FORGE_CMD

EXIT_CODE=$?
exit $EXIT_CODE
