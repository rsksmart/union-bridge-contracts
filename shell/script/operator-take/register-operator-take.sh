#!/bin/bash

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."


# Defaults
ACCEPT_PEGIN_TXID="0x0eda936375602f9cb97a435b2402d9ea96ba475de1b2555025d1db2b29e96503"

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
      echo "Usage: $0 -a <accept_pegin_txid> [--alphanet]"
      exit 1
      ;;
  esac
done
echo "================ REGISTER OPERATOR TAKE REQUEST TO $RPC ================"
forge script \
    script/RegisterOperatorTake.s.sol \
     --sig "run(bytes32)" \
    "$ACCEPT_PEGIN_TXID" \
    --rpc-url $RPC \
    --legacy \
    --broadcast \