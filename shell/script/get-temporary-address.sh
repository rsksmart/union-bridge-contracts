#!/bin/sh
#https://book.getfoundry.sh/guides/scripting-with-solidity#deploying-our-contract
source ../../.env
RPC=$LOCAL_RPC
echo "================ GET TEMPORARY ADDRESS FROM $RPC ================"
forge script \
    ../../script/GetTemporaryAddress.s.sol \
    --rpc-url $RPC \
    --legacy \
    -vvvv \