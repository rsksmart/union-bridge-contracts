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
    a) ACCEPT_PEGIN_TX_HASH=$OPTARG ;;
    t) TAKE_TXHASH=$OPTARG ;;
    \?)
      echo "Usage: $0 -m <mnemonic_index> -a <accept_pegin_tx_hash> -t <take_txhash>"
      exit 1
      ;;
  esac
done

# Enforce required args
if [ -z "$MNEMONIC_INDEX" ] || [ -z "$ACCEPT_PEGIN_TX_HASH" ] || [ -z "$TAKE_TXHASH" ]; then
  echo "Error: All three flags are required."
  echo "Usage: $0 -m <mnemonic_index> -a <accept_pegin_tx_hash> -t <take_txhash>"
  exit 1
fi

# Print info
echo "=== ADD OPERATOR TAKE TX RPC: $RPC MNEMONIC_INDEX: $MNEMONIC_INDEX ACCEPT_PEGIN_TX_HASH: $ACCEPT_PEGIN_TX_HASH TAKE_TXHASH: $TAKE_TXHASH ==="

# Run Forge script with --sig and inline args
forge script \
  script/AddOperatorTakeTxHash.s.sol \
  --sig "run(uint16,bytes32,bytes32)" "$MNEMONIC_INDEX" "$ACCEPT_PEGIN_TX_HASH" "$TAKE_TXHASH" \
  --rpc-url "$RPC" \
  --legacy \
  --broadcast \