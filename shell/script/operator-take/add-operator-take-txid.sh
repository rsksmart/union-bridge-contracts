#!/bin/bash

# Go to project root
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# Load environment
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts "m:a:t:" opt; do
  case "$opt" in
    m) MNEMONIC_INDEX=$OPTARG ;;
    a) ACCEPT_PEGIN_TXID=$OPTARG ;;
    t) TAKE_TXID=$OPTARG ;;
    \?)
      echo "Usage: $0 -m <mnemonic_index> -a <accept_pegin_txid> -t <take_txid>"
      exit 1
      ;;
  esac
done

# Enforce required args
if [ -z "$MNEMONIC_INDEX" ] || [ -z "$ACCEPT_PEGIN_TXID" ] || [ -z "$TAKE_TXID" ]; then
  echo "Error: All three flags are required."
  echo "Usage: $0 -m <mnemonic_index> -a <accept_pegin_txid> -t <take_txid>"
  exit 1
fi

# Print info
echo "=== ADD OPERATOR TAKE TX RPC: $RPC MNEMONIC_INDEX: $MNEMONIC_INDEX ACCEPT_PEGIN_TXID: $ACCEPT_PEGIN_TXID TAKE_TXID: $TAKE_TXID ==="

# Run Forge script with --sig and inline args
forge script \
  script/AddOperatorTakeTxid.s.sol \
  --sig "run(uint16,bytes32,bytes32)" "$MNEMONIC_INDEX" "$ACCEPT_PEGIN_TXID" "$TAKE_TXID" \
  --rpc-url "$RPC" \
  --legacy \
  --broadcast \