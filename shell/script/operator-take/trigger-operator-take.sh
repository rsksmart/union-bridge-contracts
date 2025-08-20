#!/bin/bash

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# Defaults
PEGOUT_SIGNATURE_HASH="0xadb3b6b14418136ab8202e57cd93615d051a38aa08bb0576420db6a1b72249ff"

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