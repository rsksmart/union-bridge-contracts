#!/bin/sh

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../.."


# Defaults
REQUEST_PEGIN_TXID="0x0f52a17b791cf01a50af91789469afb496087fb45850b4e8b43f756ad925ad20"

# set up environment variables
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts ":r:-:" opt; do
  case "$opt" in
    r) REQUEST_PEGIN_TXID="$OPTARG" ;;
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
      echo "Usage: $0 -r <request_pegin_txid> [--alphanet]"
      exit 1
      ;;
  esac
done
echo "================ ACCEPT PEGIN TO $RPC ================"
forge script \
    script/AcceptPegin.s.sol \
    --sig "run(bytes32)" \
    "$REQUEST_PEGIN_TXID" \
    --rpc-url $RPC \
    --legacy \
    --broadcast \