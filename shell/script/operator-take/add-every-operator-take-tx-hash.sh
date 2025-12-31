#!/bin/bash

set -e
source .env

# Get the directory where this script is located
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Defaults
OPERATOR_AMOUNT=3
ACCEPT_PEGIN_TXID="0x287ccabdb0e43b06ed2a4370139e9373a3fcb88625c4752e7947c5b858828115"
TAKE_TXID="0x1218969313e0736d427f4f1828fd9bfb2785df07053fe43baca6cb1a9438d349"
ALPHANET_FLAG=""

# Parse arguments
while getopts ":a:t:-:" opt; do
  case "$opt" in
    a) ACCEPT_PEGIN_TXID=$OPTARG ;;
    t) TAKE_TXID=$OPTARG ;;
    -)
      case "${OPTARG}" in
        alphanet)
          ALPHANET_FLAG="--alphanet"
          ;;
        *)
          echo "Unknown option --${OPTARG}"
          exit 1
          ;;
      esac
      ;;
    \?)
      echo "Usage: $0 [-a <accept_pegin_txid>] [-t <take_txid>] [--alphanet]"
      exit 1
      ;;
  esac
done

# Loop through all mnemonic indices
for ((i=0; i<OPERATOR_AMOUNT; i++)); do
  "$CURRENT_PATH/add-operator-take-txid.sh" -m "$i" -a "$ACCEPT_PEGIN_TXID" -t "$TAKE_TXID" $ALPHANET_FLAG
done
