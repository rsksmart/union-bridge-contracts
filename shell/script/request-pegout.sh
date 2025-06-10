#!/bin/sh

# we go to the root of the project to avoid relative path issues
current_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$current_path/../.."

# set up environment variables
source .env
RPC=$LOCAL_RPC
echo "================ REGISTER PEGOUT $RPC ================"
forge script \
    script/RequestPegout.s.sol \
    --rpc-url $RPC \
    --legacy \
    --broadcast \