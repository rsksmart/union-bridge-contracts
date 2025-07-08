#!/bin/bash

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."


# Defaults
ACCEPT_PEGIN_TX_HASH="0x3f3b22c9d1c2a322e91111b901568e441959bc4137945490e643ee6691968754"

# Parse args
while getopts ":a:" opt; do
  case "$opt" in
    a) ACCEPT_PEGIN_TX_HASH="$OPTARG" ;;
    *)
      echo "Usage: $0 -r <accept_pegin_tx_hash>"
      exit 1
      ;;
  esac
done

# set up environment variables
source .env
RPC=$LOCAL_RPC
echo "================ REGISTER OPERATOR TAKE REQUEST TO $RPC ================"
forge script \
    script/RegisterOperatorTake.s.sol \
     --sig "run(bytes32)" \
    "$ACCEPT_PEGIN_TX_HASH" \
    --rpc-url $RPC \
    --legacy \
    --broadcast \