#!/bin/sh
echo "================ SIMULATE DEPLOY ================"
# we go to the root of the project to avoid relative path issues
current_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$current_path"
cd ..
cd ..
cd ..
# openzeppelin-foundry-upgrades requires a clean build
bash shell/clean-build.sh
# remove dry runs as we have one per simulation
rm -rf broadcast/DeployScript.s.sol/31/dry-run
rm -rf cache/DeployScript.s.sol/31/dry-run
# set up environment variables
source .env
# simulate deploy
forge script script/deploy/DeployScript.s.sol \
    --rpc-url $RSK_TESTNET_RPC \
    --legacy \
    -vvv