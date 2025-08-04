#!/bin/sh

# Go to project root
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../.."

# Load environment
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts "m:s:r:t:o:a:" opt; do
  case "$opt" in
    m) MNEMONIC_INDEX=$OPTARG ;;
    s) STREAM_INDEX=$OPTARG ;;
    r) ROLE_INDEX=$OPTARG ;;
    t) TXID=$OPTARG ;;
    o) OUTPUT_INDEX=$OPTARG ;;
    a) AMOUNT=$OPTARG ;;
    \?)
      echo "Usage: $0 -m <mnemonic_index> -s <stream_index> -r <role_index> [-t <txid>] [-o <output_index>] [-a <amount>]"
      exit 1
      ;;
  esac
done

# Enforce required args
if [ -z "$MNEMONIC_INDEX" ] || [ -z "$STREAM_INDEX" ] || [ -z "$ROLE_INDEX" ]; then
  echo "Error: First three flags are required."
  echo "Usage: $0 -m <mnemonic_index> -s <stream_index> -r <role_index> [-t <txid>] [-o <output_index>] [-a <amount>]"
  exit 1
fi

# Set default UTXO values if not provided
if [ -z "$TXID" ]; then
  TXID="0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
fi
if [ -z "$OUTPUT_INDEX" ]; then
  OUTPUT_INDEX="0"
fi
if [ -z "$AMOUNT" ]; then
  AMOUNT="50000"
fi

# Print info
echo "=== APPLY TO STREAM RPC: $RPC MNEMONIC_INDEX: $MNEMONIC_INDEX STREAM_INDEX: $STREAM_INDEX ROLE_INDEX: $ROLE_INDEX TXID: $TXID OUTPUT_INDEX: $OUTPUT_INDEX AMOUNT: $AMOUNT ==="

# Run Forge script with --sig and inline args
forge script \
  script/ApplyToStream.s.sol \
  --sig "run(uint16,uint16,uint16,bytes32,uint32,uint64)" "$MNEMONIC_INDEX" "$STREAM_INDEX" "$ROLE_INDEX" "$TXID" "$OUTPUT_INDEX" "$AMOUNT" \
  --rpc-url "$RPC" \
  --legacy \
  --broadcast \