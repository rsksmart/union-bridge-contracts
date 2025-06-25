#!/bin/sh
#https://book.getfoundry.sh/guides/scripting-with-solidity#deploying-our-contract

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."
# set up environment variables
source .env
RPC=$RSK_TESTNET_RPC
echo "================ DEPLOY CONTRACTS TO $RPC ================"
# deploy to rsk testnet
forge script \
    script/deploy/DeployScript.s.sol \
    --rpc-url $RPC \
    --legacy \
    --broadcast \
    -vvvv \
    --interactives 1
    #--etherscan-api-key <your_etherscan_api_key> \
    #--verify \
