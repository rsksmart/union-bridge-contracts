#!/bin/bash

set -e
source .env

# Get the directory where this script is located
CURRENT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$CURRENT_PATH/../.."  # Go to project root

# Parse arguments
while getopts "h:s:" opt; do
  case $opt in
    h) SIGNATURE_HASH="$OPTARG" ;;
    s) SIGNATURE="$OPTARG" ;;
    \?)
      echo "Usage: $0 -h <signature_hash> -s <signature>"
      exit 1
      ;;
  esac
done

# Validate input
if [ -z "$SIGNATURE_HASH" ] || [ -z "$SIGNATURE" ]; then
  echo "Error: both -h <signature_hash> and -s <signature> must be provided"
  exit 1
fi

chmod +x "$CURRENT_PATH/add-member-signature.sh"

# Loop through all mnemonic indices
for ((i=0; i<=MAX_MNEMONIC_INDEX; i++)); do
  echo "Adding signature for member $i"
  "$CURRENT_PATH/add-member-signature.sh" -m "$i" -h "$SIGNATURE_HASH" -s "$SIGNATURE"
done
