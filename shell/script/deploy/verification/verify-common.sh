#!/bin/bash
set -e

# Usage: verify-common.sh <verifier> [broadcast-file]
# verifier: "blockscout" or "rsk-explorer" (required)
# broadcast-file: optional path to broadcast file
# Note: CHAIN_ID, BLOCKSCOUT_API, RSK_EXPLORER_API, and RSK_EXPLORER_URL should be exported by the calling script

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Validate required environment variables
if [[ -z "$CHAIN_ID" ]]; then
    echo "Error: CHAIN_ID environment variable not set. This should be exported by the calling script." >&2
    exit 1
fi

# Parse arguments
VERIFIER="$1"
BROADCAST_FILE="${2:-}"

# Validate verifier parameter
if [[ -z "$VERIFIER" ]]; then
    echo "Error: Verifier parameter required. Must be 'blockscout' or 'rsk-explorer'." >&2
    exit 1
fi

if [[ "$VERIFIER" != "blockscout" && "$VERIFIER" != "rsk-explorer" ]]; then
    echo "Error: Invalid verifier '$VERIFIER'. Must be 'blockscout' or 'rsk-explorer'." >&2
    exit 1
fi

# Verify on Blockscout
if [[ "$VERIFIER" == "blockscout" ]]; then
    if [[ "$NETWORK" == "alphanet" ]]; then
        echo "Error: Blockscout verification is not available for alphanet. Use 'rsk-explorer' instead." >&2
        exit 1
    fi
    if [[ -z "$BLOCKSCOUT_API" ]]; then
        echo "Error: BLOCKSCOUT_API environment variable not set. This should be exported by the calling script." >&2
        exit 1
    fi
    echo "================ VERIFYING ON BLOCKSCOUT ================"
    "$CURRENT_PATH/verify-blockscout.sh" "$BROADCAST_FILE"
fi

# Verify on RSK Explorer
if [[ "$VERIFIER" == "rsk-explorer" ]]; then
    if [[ -z "$RSK_EXPLORER_API" ]]; then
        echo "Error: RSK_EXPLORER_API environment variable not set. This should be exported by the calling script." >&2
        exit 1
    fi
    echo "================ VERIFYING ON RSK EXPLORER ================"
    "$CURRENT_PATH/verify-rsk-explorer.sh" "$BROADCAST_FILE"
fi
