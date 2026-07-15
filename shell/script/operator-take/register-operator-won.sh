#!/bin/bash

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."


# Defaults
ACCEPT_PEGIN_TXID="0x287ccabdb0e43b06ed2a4370139e9373a3fcb88625c4752e7947c5b858828115"
INPUT_REVEALED_TXID="0x8151e3126ff7d6d3820e457fa4be7c32da6a3ae37b3bd15b7744e3ba10c1eabb"

# set up environment variables
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts ":a:i:-:" opt; do
  case "$opt" in
    a) ACCEPT_PEGIN_TXID="$OPTARG" ;;
    i) INPUT_REVEALED_TXID="$OPTARG" ;;
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
      echo "Usage: $0 -a <accept_pegin_txid> -i <input_revealed_txid> [--alphanet]"
      exit 1
      ;;
  esac
done

echo "================ REGISTER OPERATOR WON REQUEST TO $RPC ================"
forge script \
    script/RegisterOperatorWon.s.sol \
     --sig "run(bytes32,bytes32)" \
    "$ACCEPT_PEGIN_TXID" \
    "$INPUT_REVEALED_TXID" \
    --rpc-url $RPC \
    --legacy \
    --broadcast \