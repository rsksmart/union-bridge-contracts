#!/bin/sh
echo "================ CLEAN BUILD FOR OZ ================"
# openzeppelin-foundry-upgrades requires a clean build
forge clean && forge build
echo "================ SIMULATE DEPLOY ================"
# remove dry runs as we have one per simulation
rm -rf broadcast/DeployScript.s.sol/31/dry-run
rm -rf cache/DeployScript.s.sol/31/dry-run
#https://book.getfoundry.sh/guides/scripting-with-solidity#deploying-our-contract
source .env
forge script script/DeployScript.s.sol \
    --rpc-url $RSK_TESTNET_RPC \
    --legacy \
    -vvv