#!/bin/sh

# we go to the root of the project to avoid relative path issues
current_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$current_path/../.."

# set up environment variables
source .env
RPC=$LOCAL_RPC
echo "================ REGISTER PEGIN REQUEST TO $RPC ================"
forge script \
    script/RequestPegin.s.sol \
    --rpc-url $RPC \
    --legacy \
    --broadcast \