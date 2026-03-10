#!/bin/bash

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# set up environment variables
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts ":a:-:" opt; do
  case "$opt" in
    a) ACCEPT_PEGIN_TXID="$OPTARG" ;;
    -)
      case "${OPTARG}" in
        alphanet)
          RPC=$RSK_ALPHANET_RPC
          export NETWORK=alphanet
          ;;
        *)
          echo "Unknown option --${OPTARG}"
          exit 1
          ;;
      esac
      ;;
    *)
      echo "Usage: $0 -h <ACCEPT_PEGIN_TXID> [--alphanet]"
      exit 1
      ;;
  esac
done

# Enforce required args
if [ -z "$ACCEPT_PEGIN_TXID" ]; then
  echo "Error: ACCEPT_PEGIN_TXID is required."
  echo "Usage: $0 -a <accept_pegin_txid>"
  exit 1
fi

echo "================ TRIGGER OPERATOR TAKE REQUEST TO $RPC ================"
echo "ACCEPT_PEGIN_TXID: $ACCEPT_PEGIN_TXID "

forge script \
    script/TriggerOperatorTake.s.sol \
     --sig "run(bytes32)" \
    "$ACCEPT_PEGIN_TXID" \
    --rpc-url $RPC \
    --legacy \
    --broadcast \