#!/bin/bash

set -e
source .env

# Get the directory where this script is located
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Defaults
OPERATOR_AMOUNT=3
ACCEPT_PEGIN_TX_HASH="0x73d69e28cbe4ffc75b786b5dae8086a8112f6eb793d6891f2f900aac968a78ea"
TAKE_TXHASH="0x1218969313e0736d427f4f1828fd9bfb2785df07053fe43baca6cb1a9438d349"

# Parse arguments
while getopts ":a:t:" opt; do
  case "$opt" in
    a) ACCEPT_PEGIN_TX_HASH=$OPTARG ;;
    t) TAKE_TXHASH=$OPTARG ;;
    \?)
      echo "Usage: $0 -a <accept_pegin_tx_hash> -t <take_txhash>"
      exit 1
      ;;
  esac
done

# Loop through all mnemonic indices
for ((i=0; i<OPERATOR_AMOUNT; i++)); do
  "$CURRENT_PATH/add-operator-take-tx-hash.sh" -m "$i" -a "$ACCEPT_PEGIN_TX_HASH" -t "$TAKE_TXHASH"
done
