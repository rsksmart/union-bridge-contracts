#!/bin/sh
#https://book.getfoundry.sh/guides/scripting-with-solidity#deploying-our-contract
echo "================ SIMULATE DEPLOY ================"
rm -rf broadcast/Deploy.s.sol/31/dry-run
rm -rf cache/Deploy.s.sol/31/dry-run
source .env
SCRIPT=script/Deploy.s.sol
RPC=$RSK_TESTNET_RPC
forge script $SCRIPT \
    --rpc-url $RPC \
    --legacy \
    -vvv