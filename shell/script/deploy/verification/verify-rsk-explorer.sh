#!/bin/bash
set -e

# Script to verify all contracts on RSK Explorer using the API
# Usage: ./verify-rsk-explorer.sh [broadcast-file]
# Note: CHAIN_ID, RSK_EXPLORER_API, and RSK_EXPLORER_URL should be exported by the calling script

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

if [ -z "$RSK_EXPLORER_API" ]; then
    echo "Error: RSK_EXPLORER_API environment variable not set. This should be exported by the calling script." >&2
    exit 1
fi

# Set verifier-specific configuration
VERIFIER="custom"
TITLE="RSK Explorer Contract Verification"
API_URL="$RSK_EXPLORER_API"
EXPLORER_URL="${RSK_EXPLORER_URL:-}"

# Run verification
verify_all_contracts "$VERIFIER" "$API_URL" "$EXPLORER_URL" "$TITLE" "$CHAIN_ID" "$BROADCAST_FILE"
