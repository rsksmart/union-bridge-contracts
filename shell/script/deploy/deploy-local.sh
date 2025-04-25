#!/bin/sh
# Anvil deploy https://book.getfoundry.sh/reference/anvil/
# we go to the root of the project to avoid relative path issues
current_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$current_path"
cd ..
cd ..
cd ..
# openzeppelin-foundry-upgrades requires a clean build
bash shell/clean-build.sh
# set up environment variables
source .env
echo "================ RPC_URL: $RPC_URL ================"
if [[ -z "${RPC_URL}" ]]; then
  RPC=$LOCAL_RPC
else
  RPC=$RPC_URL
fi
echo "================ PRIVATE_KEY: $PRIVATE_KEY ================"
if [[ -z "${PRIVATE_KEY}" ]]; then
  # Anvil Private Key
  echo "YOU NEED TO DEFINE ENV VARIABLE PRIVATE_KEY"
  exit 1
else
  DELPOY_PRIVATE_KEY=$PRIVATE_KEY
fi
echo "================ DEPLOY CONTRACTS TO $RPC ================"
# deploy to local anvil
forge script \
    script/deploy/DeployScript.s.sol \
    --rpc-url $RPC \
    --legacy \
    --broadcast \
    -v \
    --private-key $DELPOY_PRIVATE_KEY \