#!/bin/sh
#https://book.getfoundry.sh/guides/scripting-with-solidity#deploying-our-contract
source ../../../.env
RPC=$RSK_TESTNET_RPC
echo "================ DEPLOY CONTRACTS TO $RPC ================"
forge script \
    ../../../script/deploy/DeployScript.s.sol \
    --rpc-url $RPC \
    --legacy \
    --broadcast \
    -vvvv \
    --interactives 1
    #--etherscan-api-key <your_etherscan_api_key> \
    #--verify \
