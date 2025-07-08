#!/bin/bash

set -e
source .env

# Get the directory where this script is located
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."  # Go to project root

# Parse arguments
while getopts "h:n:" opt; do
  case $opt in
    h) SIGNATURE_HASH="$OPTARG" ;;
    n) NONCE="$OPTARG" ;;
    \?)
      echo "Usage: $0 -h <signature_hash> -n <nonce>"
      exit 1
      ;;
  esac
done

# Validate input
if [ -z "$SIGNATURE_HASH" ] || [ -z "$NONCE" ]; then
  echo "Error: both -h <signature_hash> and -n <nonce> must be provided"
  exit 1
fi

# Loop through all mnemonic indices
for ((i=0; i<=MAX_MNEMONIC_INDEX; i++)); do
  #echo "Adding nonce for member $i"
  "$CURRENT_PATH/add-member-nonce.sh" -m "$i" -h "$SIGNATURE_HASH" -n "$NONCE"
done
