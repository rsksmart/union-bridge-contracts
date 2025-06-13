#!/bin/bash

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."  # Go to project root

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

chmod +x "$SCRIPT_DIR/add-member-nonce.sh"

# Loop through all members (mnemonic indices 0 to 9)
for i in {0..9}; do
  echo "Adding nonce for member $i"
  "$SCRIPT_DIR/add-member-nonce.sh" -m "$i" -h "$SIGNATURE_HASH" -n "$NONCE"
done
