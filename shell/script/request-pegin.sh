#!/bin/sh

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../.."

# Defaults
RSK_DESTINATION_ADDRESS="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

# set up environment variables
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts ":a:-:" opt; do
  case "$opt" in
    a) RSK_DESTINATION_ADDRESS="$OPTARG" ;;
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
      echo "Usage: $0 -a <rsk_destination_address> [--alphanet]"
      exit 1
      ;;
  esac
done
echo "================ REGISTER PEGIN REQUEST TO $RPC ================"
forge script \
    script/RequestPegin.s.sol \
    --sig "run(address)" \
    "$RSK_DESTINATION_ADDRESS" \
    --rpc-url $RPC \
    --legacy \
    --broadcast \