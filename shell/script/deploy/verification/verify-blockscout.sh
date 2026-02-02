#!/bin/bash
set -e

# Script to verify all contracts on Blockscout using the API
# Usage: ./verify-blockscout.sh [broadcast-file]
# Note: CHAIN_ID and BLOCKSCOUT_API should be exported by the calling script

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Source common verification functions
source "$CURRENT_PATH/verify-all.sh"

# Parse arguments
BROADCAST_FILE="${1:-}"

# Validate required environment variables
if [ -z "$CHAIN_ID" ]; then
    echo "Error: CHAIN_ID environment variable not set. This should be exported by the calling script." >&2
    exit 1
fi

if [ -z "$BLOCKSCOUT_API" ]; then
    echo "Error: BLOCKSCOUT_API environment variable not set. This should be exported by the calling script." >&2
    exit 1
fi

# Set verifier-specific configuration
VERIFIER="blockscout"
TITLE="Blockscout Contract Verification"
API_URL="$BLOCKSCOUT_API"

# Remove /api at the end to get explorer URL
EXPLORER_URL="${API_URL%/api}"
EXPLORER_URL="${EXPLORER_URL%/}/"

# Run verification
verify_all_contracts "$VERIFIER" "$API_URL" "$EXPLORER_URL" "$TITLE" "$CHAIN_ID" "$BROADCAST_FILE"
