#!/bin/sh

# Go to project root
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../.."

# Load environment
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts "m:s:t:d:-:" opt; do
  case "$opt" in
    m) MNEMONIC_INDEX=$OPTARG ;;
    s) STREAM_INDEX=$OPTARG ;;
    t) COMMITTEE_TAKE_PUBKEY=$OPTARG ;;
    d) COMMITTEE_DISPUTE_PUBKEY=$OPTARG ;;
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
      echo "Usage: $0 -d <committee_dispute_pubkey> -m <mnemonic_index> -s <stream_index> -t <committee_take_pubkey> [--alphanet]"
      exit 1
      ;;
  esac
done

# Enforce required args
if [ -z "$MNEMONIC_INDEX" ] || [ -z "$STREAM_INDEX" ] || [ -z "$COMMITTEE_TAKE_PUBKEY" ] || [ -z "$COMMITTEE_DISPUTE_PUBKEY" ]; then
  echo "Error: All four flags are required."
  echo "Usage: $0 -d <committee_dispute_pubkey> -m <mnemonic_index> -s <stream_index> -t <committee_take_pubkey>"
  exit 1
fi

# Print info
echo "=== DEPOSIT AGGREGATED KEYS RPC: $RPC MNEMONIC_INDEX: $MNEMONIC_INDEX STREAM_INDEX: $STREAM_INDEX COMMITTEE_TAKE_PUBKEY: $COMMITTEE_TAKE_PUBKEY COMMITTEE_DISPUTE_PUBKEY: $COMMITTEE_DISPUTE_PUBKEY ==="

# Run Forge script with --sig and inline args
forge script \
  script/DepositAggregatedKeys.s.sol \
  --sig "run(uint16,uint64,bytes,bytes)" "$MNEMONIC_INDEX" "$STREAM_INDEX" "$COMMITTEE_TAKE_PUBKEY" "$COMMITTEE_DISPUTE_PUBKEY" \
  --rpc-url "$RPC" \
  --legacy \
  --broadcast \