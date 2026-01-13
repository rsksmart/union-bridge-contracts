#!/bin/sh

# Script to advance Bitcoin block height in BridgeMock
# Usage: ./advance-bitcoin-blocks.sh -b <blocks_to_advance>

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../.."

# Defaults
BLOCKS_TO_ADVANCE=""

# set up environment variables
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts ":b:-:" opt; do
  case "$opt" in
    b) BLOCKS_TO_ADVANCE="$OPTARG" ;;
    -)
      case "${OPTARG}" in
        alphanet)
          RPC=$RSK_ALPHANET_RPC
          export NETWORK=alphanet
          ;;
        *)
          echo "Unknown option --${OPTARG}"
          exit 1
          ;;
      esac
      ;;
    *)
      echo "Usage: $0 -b <blocks_to_advance> [--alphanet]"
      echo "Example: $0 -b 1"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [ -z "$BLOCKS_TO_ADVANCE" ]; then
    echo "Error: Number of blocks to advance is required"
    echo "Usage: $0 -b <blocks_to_advance>"
    echo "Example: $0 -b 1"
    exit 1
fi

echo "================ ADVANCE BITCOIN BLOCKS ON $RPC ================"
echo "Blocks to advance: $BLOCKS_TO_ADVANCE"

forge script \
    script/AdvanceBitcoinBlocks.s.sol \
    --sig "run(int256)" \
    "$BLOCKS_TO_ADVANCE" \
    --rpc-url $RPC \
    --legacy \
    --broadcast
