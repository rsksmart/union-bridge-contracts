#!/bin/sh

# Go to project root
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../.."

# Load environment
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts "m:" opt; do
  case $opt in
    m) MNEMONIC_INDEX="$OPTARG" ;;
    *)
      echo "Usage: $0 -m <mnemonic_index>"
      exit 1
      ;;
  esac
done

# Enforce required arg
if [ -z "$MNEMONIC_INDEX" ]; then
  echo "Error: Flag is required."
  echo "Usage: $0 -m <mnemonic_index>"
  exit 1
fi

# Print info
echo "=== MNEMONIC_INDEX TO WHITELIST: $MNEMONIC_INDEX ==="

# Run Forge script with --sig and inline args
forge script \
  script/WhitelistAddress.s.sol \
  --sig "run(uint16)" "$MNEMONIC_INDEX" \
  --rpc-url "$RPC" \
  --legacy \
  --broadcast \