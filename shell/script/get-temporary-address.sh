#!/bin/sh

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../.."

# set up environment variables
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts ":-:" opt; do
  case "$opt" in
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
      echo "Usage: $0 [--alphanet]"
      exit 1
      ;;
  esac
done

echo "================ GET TEMPORARY ADDRESS FROM $RPC ================"
forge script \
    script/GetTemporaryAddress.s.sol \
    --rpc-url $RPC \
    --legacy \