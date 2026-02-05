#!/bin/bash

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# Defaults
PEGOUT_TXID="0xadb3b6b14418136ab8202e57cd93615d051a38aa08bb0576420db6a1b72249ff"

# set up environment variables
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts ":h:-:" opt; do
  case "$opt" in
    h) PEGOUT_TXID="$OPTARG" ;;
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
      echo "Usage: $0 -h <PEGOUT_TXID> [--alphanet]"
      exit 1
      ;;
  esac
done
echo "================ TRIGGER OPERATOR TAKE REQUEST TO $RPC ================"
echo "PEGOUT_TXID: $PEGOUT_TXID "

forge script \
    script/TriggerOperatorTake.s.sol \
     --sig "run(bytes32)" \
    "$PEGOUT_TXID" \
    --rpc-url $RPC \
    --legacy \
    --broadcast \