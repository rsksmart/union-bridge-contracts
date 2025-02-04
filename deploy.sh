#!/bin/sh
#https://book.getfoundry.sh/guides/scripting-with-solidity#deploying-our-contract
bash simulate-deploy.sh
echo "================ DEPLOY CONTRACTS TO $RSK_TESTNET_RPC ================"
forge script \
    $SCRIPT \
    --rpc-url $RSK_TESTNET_RPC \
    --legacy \
    --broadcast \
    -vvvv \
    --interactives 1
    #--etherscan-api-key <your_etherscan_api_key> \
    #--verify \
