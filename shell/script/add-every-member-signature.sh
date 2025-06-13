#!/bin/bash

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../.."  # Go to project root

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

chmod +x "$SCRIPT_DIR/add-member-signature.sh"

# Loop through all members (mnemonic indices 0 to 9)
for i in {0..9}; do
  echo "Adding signature for member $i"
  "$SCRIPT_DIR/add-member-signature.sh" -m "$i" -h "$SIGNATURE_HASH" -s "$SIGNATURE"
done
