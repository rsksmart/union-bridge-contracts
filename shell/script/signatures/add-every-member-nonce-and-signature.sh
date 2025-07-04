#!/bin/bash
set -e

# Defaults
NONCE="0xf8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000"
SIGNATURE="0xf8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0"

usage() {
  echo "Usage: $0 [-h signature_hash] [-n nonce] [-s signature]"
  exit 1
}

# Parse args
while getopts ":h:n:s:" opt; do
  case "$opt" in
    h) SIGNATURE_HASH="$OPTARG" ;;
    n) NONCE="$OPTARG" ;;
    s) SIGNATURE="$OPTARG" ;;
    *) usage ;;
  esac
done

# Go to script dir
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Run both scripts
bash "$CURRENT_PATH/add-every-member-nonce.sh" -h "$SIGNATURE_HASH" -n "$NONCE"
bash "$CURRENT_PATH/add-every-member-signature.sh" -h "$SIGNATURE_HASH" -s "$SIGNATURE"