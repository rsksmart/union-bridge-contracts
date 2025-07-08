#!/bin/bash

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../.."

# set up environment variables
source .env
RPC=$LOCAL_RPC
echo "================ REGISTER PEGOUT $RPC ================"
forge script \
    script/TryPegout.s.sol \
    --rpc-url $RPC \
    --legacy \
    --broadcast \