#!/bin/sh

# Go to project root
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../.."

# Load environment
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts "m:s:p:" opt; do
  case "$opt" in
    m) MNEMONIC_INDEX=$OPTARG ;;
    s) STREAM_INDEX=$OPTARG ;;
    p) COMMITTEE_PUBKEY=$OPTARG ;;
    \?)
      echo "Usage: $0 -m <mnemonic_index> -s <stream_index> -p <committee_pubkey>"
      exit 1
      ;;
  esac
done

# Enforce required args
if [ -z "$MNEMONIC_INDEX" ] || [ -z "$STREAM_INDEX" ] || [ -z "$COMMITTEE_PUBKEY" ]; then
  echo "Error: All three flags are required."
  echo "Usage: $0 -m <mnemonic_index> -s <stream_index> -p <committee_pubkey>"
  exit 1
fi

# Print info
echo "=== DEPOSIT AGGREGATED KEY RPC: $RPC MNEMONIC_INDEX: $MNEMONIC_INDEX STREAM_INDEX: $STREAM_INDEX COMMITTEE_PUBKEY: $COMMITTEE_PUBKEY ==="

# Run Forge script with --sig and inline args
forge script \
  script/DepositAggregatedKey.s.sol \
  --sig "run(uint16,uint64,bytes32)" "$MNEMONIC_INDEX" "$STREAM_INDEX" "$COMMITTEE_PUBKEY" \
  --rpc-url "$RPC" \
  --legacy \
  --broadcast \