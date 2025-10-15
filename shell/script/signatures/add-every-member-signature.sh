#!/bin/bash

set -e
source .env

# Get the directory where this script is located
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

ALPHANET_FLAG=""

# Parse arguments
while getopts "h:s:-:" opt; do
  case $opt in
    h) TXID="$OPTARG" ;;
    s) SIGNATURE="$OPTARG" ;;
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
      echo "Usage: $0 -h <txid> -s <signature> [--alphanet]"
      exit 1
      ;;
  esac
done

# Validate input
if [ -z "$TXID" ] || [ -z "$SIGNATURE" ]; then
  echo "Error: both -h <txid> and -s <signature> must be provided"
  exit 1
fi

# Loop through all mnemonic indices
for ((i=0; i<=MAX_MNEMONIC_INDEX; i++)); do
  #echo "Adding signature for member $i"
  "$CURRENT_PATH/add-member-signature.sh" -m "$i" -h "$TXID" -s "$SIGNATURE" $ALPHANET_FLAG
done
