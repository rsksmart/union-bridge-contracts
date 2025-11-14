#!/bin/sh

# Go to project root
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../.."

# Load environment
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts "-:" opt; do
  case "$opt" in
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
    \?)
      echo "Usage: $0 [--alphanet]"
      exit 1
      ;;
  esac
done

echo "=== FUNDING BRIDGE MOCK RPC: $RPC ==="

# Run Forge script
forge script \
  script/FundBridgeMock.s.sol \
  --rpc-url "$RPC" \
  --legacy \
  --broadcast \
  -v
