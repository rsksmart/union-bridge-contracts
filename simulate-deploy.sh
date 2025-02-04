#!/bin/sh
#https://book.getfoundry.sh/guides/scripting-with-solidity#deploying-our-contract
echo "================ SIMULATE DEPLOY ================"
rm -rf broadcast/Deploy.s.sol/31/dry-run
rm -rf cache/Deploy.s.sol/31/dry-run
source .env
SCRIPT=script/Deploy.s.sol
forge script $SCRIPT — compile
forge script $SCRIPT \
    --rpc-url $RSK_TESTNET_RPC \
    --legacy \
    -vvv