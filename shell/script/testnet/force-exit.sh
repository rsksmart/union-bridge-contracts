#!/bin/bash

# Script to force exit the contract withdrawing all the balance to an address
# Usage: ./force-exit.sh -a <address> 

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# Defaults
ADDRESS=""

# set up environment variables
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts ":a:" opt; do
  case "$opt" in
    a) ADDRESS="$OPTARG" ;;
    *)
      echo "Usage: $0 -a <address>"
      echo "Example: $0 -a 0x123...456..."
      exit 1
      ;;
  esac
done

# Validate required arguments
if [ -z "$ADDRESS" ]; then
    echo "Error: All parameters are required"
    echo "Usage: $0 -a <address>"
    exit 1
fi

echo "================ FORCE EXIT FOR TESTNET ONLY FROM $RPC ================"
echo "Address: $ADDRESS"

forge script \
    script/testnet/ForceExit.s.sol \
    --sig "run(address)" \
    "$ADDRESS" \
    --rpc-url $RPC \
    --legacy \
    --broadcast \
    --slow \
    -vvv