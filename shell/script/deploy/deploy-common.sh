#!/bin/bash
set -e
#https://book.getfoundry.sh/guides/scripting-with-solidity#deploying-our-contract

# Usage: deploy-common.sh [verify]
# verify: optional, true or false (defaults to true if not provided)
# Note: NETWORK and other network-specific variables should be exported by the calling script

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# Validate NETWORK is set (should be exported by calling script)
if [[ -z "$NETWORK" ]]; then
    echo "Error: NETWORK environment variable not set. This should be exported by the calling deploy script."
    exit 1
fi

# Set VERIFY from argument (defaults to true)
if [[ "$1" == "false" ]]; then
    VERIFY=false
else
    VERIFY=true
fi

if [[ -z "$RPC" ]]; then
    echo "Error: RPC URL not set for network '$NETWORK'"
    exit 1
fi

echo "================ DEPLOY CONTRACTS TO $NETWORK: $RPC ================"

# Mainnet warning
if [[ "$NETWORK" == "mainnet" ]]; then
    echo "WARNING: You are about to deploy to RSK MAINNET"
    echo "Type 'yes' to continue, or anything else to cancel:"
    read -r confirmation
    if [[ "$confirmation" != "yes" ]]; then
        echo "Deployment cancelled."
        exit 1
    fi
fi

# Deploy forge script command
FORGE_CMD="forge script \
    script/deploy/DeployScript.s.sol \
    --rpc-url $RPC \
    --legacy \
    --broadcast \
    --slow \
    -vvv"

# Only use --interactives in non-CI environments
if [[ -z "$IS_TEST" && -z "$CI" && -t 0 ]]; then
    FORGE_CMD="$FORGE_CMD --interactives 1"
fi

# Add verification for testnet/mainnet/alphanet (only if RSK_EXPLORER_API is set)
if [[ "$VERIFY" == "true" && -n "$RSK_EXPLORER_API" ]]; then
    FORGE_CMD="$FORGE_CMD --verify --verifier custom --verifier-url $RSK_EXPLORER_API"
fi

# Add gas-price from .env (if set)
if [[ -n "$GAS_PRICE_IN_WEIS" ]]; then
    FORGE_CMD="$FORGE_CMD --gas-price $GAS_PRICE_IN_WEIS"
fi

# Execute deployment
eval $FORGE_CMD

DEPLOY_EXIT_CODE=$?

# Verify on Blockscout after successful deployment (testnet/mainnet only, not alphanet)
if [[ "$VERIFY" == "true" && -n "$BLOCKSCOUT_API" && "$NETWORK" != "alphanet" && $DEPLOY_EXIT_CODE -eq 0 ]]; then
    echo ""
    echo "================ VERIFYING ON BLOCKSCOUT ================"
    "$CURRENT_PATH/verification/verify-blockscout.sh"
elif [[ $DEPLOY_EXIT_CODE -ne 0 ]]; then
    echo ""
    echo "Deployment failed. Skipping contract verification."
    exit $DEPLOY_EXIT_CODE
fi

exit $DEPLOY_EXIT_CODE
