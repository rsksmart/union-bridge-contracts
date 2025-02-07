#!/bin/sh
#https://book.getfoundry.sh/guides/scripting-with-solidity#deploying-our-contract
echo "================ SIMULATE DEPLOY ================"
rm -rf broadcast/01_Deploy.s.sol/31/dry-run
rm -rf cache/01_Deploy.s.sol/31/dry-run
source .env
forge script script/01_Deploy.s.sol \
    --rpc-url $RSK_TESTNET_RPC \
    --legacy \
    -vvv