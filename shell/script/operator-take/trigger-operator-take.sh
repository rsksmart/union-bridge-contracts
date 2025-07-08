#!/bin/bash

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# Defaults
PEGOUT_SIGNATURE_HASH="0x7e00ec037f2ac760a440f781ac4f344bea7c7b3e4869a7793c4c6050c83d9e22"

# Parse args
while getopts ":p:" opt; do
  case "$opt" in
    p) PEGOUT_SIGNATURE_HASH="$OPTARG" ;;
    *)
      echo "Usage: $0 -p <pegout_signature_hash>"
      exit 1
      ;;
  esac
done

# set up environment variables
source .env
RPC=$LOCAL_RPC
echo "================ TRIGGER OPERATOR TAKE REQUEST TO $RPC ================"
forge script \
    script/TriggerOperatorTake.s.sol \
     --sig "run(bytes32)" \
    "$PEGOUT_SIGNATURE_HASH" \
    --rpc-url $RPC \
    --legacy \
    --broadcast \