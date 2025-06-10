#!/bin/sh

# Go to project root
current_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$current_path/../.."

# Load environment
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts "m:s:r:" opt; do
  case "$opt" in
    m) MNEMONIC_INDEX=$OPTARG ;;
    s) STREAM_INDEX=$OPTARG ;;
    r) ROLE_INDEX=$OPTARG ;;
    \?)
      echo "Usage: $0 -m <mnemonic_index> -s <stream_index> -r <role_index>"
      exit 1
      ;;
  esac
done

# Enforce required args
if [ -z "$MNEMONIC_INDEX" ] || [ -z "$STREAM_INDEX" ] || [ -z "$ROLE_INDEX" ]; then
  echo "Error: All three flags are required."
  echo "Usage: $0 -m <mnemonic_index> -s <stream_index> -r <role_index>"
  exit 1
fi

# Print info
echo "=== APPLY TO STREAM ==="
echo "RPC: $RPC"
echo "MNEMONIC_INDEX: $MNEMONIC_INDEX"
echo "STREAM_INDEX: $STREAM_INDEX"
echo "ROLE_INDEX: $ROLE_INDEX"

# Run Forge script with --sig and inline args
forge script \
  script/ApplyToStream.s.sol \
  --sig "run(uint16,uint16,uint16)" "$MNEMONIC_INDEX" "$STREAM_INDEX" "$ROLE_INDEX" \
  --rpc-url "$RPC" \
  --legacy \
  --broadcast \