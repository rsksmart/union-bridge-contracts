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
RPC=$LOCAL_RPC
echo "================ DEPLOY CONTRACTS TO $RPC ================"
# deploy to local anvil
forge script \
    script/deploy/DeployScript.s.sol \
    --rpc-url $RPC \
    --legacy \
    --broadcast \
    -vvvv \
    --interactives 1 \