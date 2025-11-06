#!/bin/bash
set -e
# Anvil deploy https://book.getfoundry.sh/reference/anvil/
# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# set up environment variables
source .env
echo "================ RPC_URL: $RPC_URL ================"
if [[ -z "${RPC_URL}" ]]; then
  RPC=$LOCAL_RPC
else
  RPC=$RPC_URL
fi
echo "================ MNEMONIC: $MNEMONIC ================"
if [[ -z "${MNEMONIC}" ]]; then
  # Anvil Private Key
  echo "MNEMONIC STRING VARIABLE NEEDS TO BE DEFINED IN THE ENV FILE"
  exit 1
fi
echo "================ DEPLOY CONTRACTS TO $RPC ================"
# deploy to local anvil
forge script \
    script/deploy/DeployScript.s.sol \
    --rpc-url $RPC \
    --legacy \
    --broadcast \
    -v \
    --slow \