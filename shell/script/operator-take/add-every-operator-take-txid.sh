#!/bin/bash

set -e
source .env

# Get the directory where this script is located
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Defaults
OPERATOR_AMOUNT=3
ACCEPT_PEGIN_TXID="0x57450e6c6141e63115cf56fc9fd8c29e20792a8c488c3d9e2bd99edac6496ffc"
TAKE_TXID="0x1218969313e0736d427f4f1828fd9bfb2785df07053fe43baca6cb1a9438d349"
WON_TXID="0x1218969313e0736d427f4f1828fd9bfb2785df07053fe43baca6cb1a9438d349"

ALPHANET_FLAG=""

# Parse arguments
while getopts ":a:t:w:-:" opt; do
  case "$opt" in
    a) ACCEPT_PEGIN_TXID=$OPTARG ;;
    t) TAKE_TXID=$OPTARG ;;
    w) WON_TXID=$OPTARG ;;
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
      echo "Usage: $0 [-a <accept_pegin_txid>] [-t <take_txid>] [-w <won_txid>] [--alphanet]"
      exit 1
      ;;
  esac
done

# Loop through all mnemonic indices
for ((i=0; i<OPERATOR_AMOUNT; i++)); do
  "$CURRENT_PATH/add-operator-take-txid.sh" -m "$i" -a "$ACCEPT_PEGIN_TXID" -t "$TAKE_TXID" -w "$WON_TXID" $ALPHANET_FLAG
done
