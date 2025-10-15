#!/bin/sh

# Go to project root
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../.."

# Load environment
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts "m:s:-:" opt; do
  case "$opt" in
    m) MNEMONIC_INDEX=$OPTARG ;;
    s) STREAM_INDEX=$OPTARG ;;
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
      echo "Usage: $0 -m <mnemonic_index> -s <stream_index> [--alphanet]"
      exit 1
      ;;
  esac
done

# Enforce required args
if [ -z "$MNEMONIC_INDEX" ] || [ -z "$STREAM_INDEX" ]; then
  echo "Error: All three flags are required."
  echo "Usage: $0 -m <mnemonic_index> -s <stream_index>"
  exit 1
fi

# Print info
echo "=== GET COMMUNICATION DATA FOR ONE MEMBER RPC: $RPC MNEMONIC_INDEX: $MNEMONIC_INDEX STREAM_INDEX: $STREAM_INDEX ==="

# Run Forge script with --sig and inline args
forge script \
  script/GetCommunicationDataForOneMember.s.sol \
  --sig "run(uint16,uint64)" "$MNEMONIC_INDEX" "$STREAM_INDEX" \
  --rpc-url "$RPC" \
  --legacy \
  --broadcast \