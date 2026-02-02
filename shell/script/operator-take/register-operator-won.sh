#!/bin/bash

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."


# Defaults
ACCEPT_PEGIN_TXID="0x287ccabdb0e43b06ed2a4370139e9373a3fcb88625c4752e7947c5b858828115"
PEGOUT_ID="0xdf1624a2037eb79a82ab3a1b783ab12b3b58df14fa74966fdd98102a9e29ac02"

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

echo "================ REGISTER OPERATOR WON REQUEST TO $RPC ================"
forge script \
    script/RegisterOperatorWon.s.sol \
     --sig "run(bytes32, bytes32)" \
    "$ACCEPT_PEGIN_TXID" \
    "$PEGOUT_ID" \
    --rpc-url $RPC \
    --legacy \
    --broadcast \