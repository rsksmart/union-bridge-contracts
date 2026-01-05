#!/bin/bash

set -e
source .env

# Get the directory where this script is located
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Defaults
OPERATOR_AMOUNT=3

ALPHANET_FLAG=""

# Parse arguments
while getopts ":a:-:" opt; do
  case "$opt" in
    a) ACCEPT_PEGIN_TXID=$OPTARG ;;
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
      echo "Usage: $0 -a <accept_pegin_txid> [--alphanet]"
      exit 1
      ;;
  esac
done

# Loop through all mnemonic indices
for ((i=0; i<OPERATOR_AMOUNT; i++)); do
  "$CURRENT_PATH/add-operator-take-txid.sh" -m "$i" -a "$ACCEPT_PEGIN_TXID" $ALPHANET_FLAG
done
