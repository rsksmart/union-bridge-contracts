#!/bin/bash

set -e
source .env

# Get the directory where this script is located
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Parse arguments
while getopts "h:s:" opt; do
  case $opt in
    h) TX_HASH="$OPTARG" ;;
    s) SIGNATURE="$OPTARG" ;;
    \?)
      echo "Usage: $0 -h <tx_hash> -s <signature>"
      exit 1
      ;;
  esac
done

# Validate input
if [ -z "$TX_HASH" ] || [ -z "$SIGNATURE" ]; then
  echo "Error: both -h <tx_hash> and -s <signature> must be provided"
  exit 1
fi

# Loop through all mnemonic indices
for ((i=0; i<=MAX_MNEMONIC_INDEX; i++)); do
  #echo "Adding signature for member $i"
  "$CURRENT_PATH/add-member-signature.sh" -m "$i" -h "$TX_HASH" -s "$SIGNATURE"
done
