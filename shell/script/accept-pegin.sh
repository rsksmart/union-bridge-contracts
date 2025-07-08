#!/bin/sh

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../.."


# Defaults
REQUEST_PEGIN_TX_HASH="0x9a40f6df4226a822b1b952d41d490a3ab91f1826b684c56a05d75be16f0eb088"

# Parse args
while getopts ":r:" opt; do
  case "$opt" in
    r) REQUEST_PEGIN_TX_HASH="$OPTARG" ;;
    *)
      echo "Usage: $0 -r <request_pegin_tx_hash>"
      exit 1
      ;;
  esac
done

# set up environment variables
source .env
RPC=$LOCAL_RPC
echo "================ ACCEPT PEGIN TO $RPC ================"
forge script \
    script/AcceptPegin.s.sol \
    --sig "run(bytes32)" \
    "$REQUEST_PEGIN_TX_HASH" \
    --rpc-url $RPC \
    --legacy \
    --broadcast \