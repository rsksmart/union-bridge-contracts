#!/bin/sh
#https://book.getfoundry.sh/guides/scripting-with-solidity#deploying-our-contract
bash simulate-deploy.sh
echo "================ DEPLOY CONTRACTS TO $RPC ================"
forge script \
    $SCRIPT \
    --rpc-url $RPC \
    --legacy \
    --broadcast \
    -vvvv \
    --interactives 1
    #--etherscan-api-key <your_etherscan_api_key> \
    #--verify \
