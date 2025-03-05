#!/bin/sh
# Anvil deploy https://book.getfoundry.sh/reference/anvil/
echo "================ CLEAN BUILD FOR OZ ================"
# openzeppelin-foundry-upgrades requires a clean build
forge clean && forge build
source ../../../.env
RPC=$LOCAL_RPC
echo "================ DEPLOY CONTRACTS TO $RPC ================"
forge script \
    ../../../script/deploy/DeployScript.s.sol \
    --rpc-url $RPC \
    --legacy \
    --broadcast \
    -vvvv \
    --interactives 1 \