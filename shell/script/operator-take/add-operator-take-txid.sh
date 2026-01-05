#!/bin/bash

# Go to project root
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# Load environment
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts "m:a:t:w:-:" opt; do
  case "$opt" in
    m) MNEMONIC_INDEX=$OPTARG ;;
    a) ACCEPT_PEGIN_TXID=$OPTARG ;;
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
      echo "Usage: $0 -m <mnemonic_index> -a <accept_pegin_txid> [--alphanet]"
      exit 1
      ;;
  esac
done

# Enforce required args
if [ -z "$MNEMONIC_INDEX" ] || [ -z "$ACCEPT_PEGIN_TXID" ]; then
  echo "Error: All four flags are required."
  echo "Usage: $0 -m <mnemonic_index> -a <accept_pegin_txid>"
  exit 1
fi

# Print info
echo "=== ADD OPERATOR TAKE TX RPC: $RPC MNEMONIC_INDEX: $MNEMONIC_INDEX ACCEPT_PEGIN_TXID: $ACCEPT_PEGIN_TXID ==="

# Run Forge script with --sig and inline args
forge script \
  script/AddOperatorTakeTxid.s.sol \
  --sig "run(uint16,bytes32)" "$MNEMONIC_INDEX" "$ACCEPT_PEGIN_TXID" \
  --rpc-url "$RPC" \
  --legacy \
  --broadcast \