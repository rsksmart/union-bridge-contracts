#!/bin/bash

# Script to force release committees for a stream
# Usage: ./force-committe-release.sh -s <stream_id> 

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# Defaults
STREAM_ID=""

# set up environment variables
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts ":s:" opt; do
  case "$opt" in
    s) STREAM_ID="$OPTARG" ;;
    *)
      echo "Usage: $0 -s <stream_id>"
      echo "Example: $0 -s 1"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [ -z "$STREAM_ID" ]; then
    echo "Error: All parameters are required"
    echo "Usage: $0 -s <stream_id>"
    exit 1
fi

echo "================ FORCE RELEASE COMMITTEE FOR TESTNET ONLY FROM $RPC ================"
echo "Stream ID: $STREAM_ID"

forge script \
    script/testnet/ForceCloseCommittee.s.sol \
    --sig "run(uint64)" \
    "$STREAM_ID" \
    --rpc-url $RPC \
    --legacy \
    --broadcast \
    --slow \
    -vvv