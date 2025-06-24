#!/bin/sh

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# set up environment variables
source .env
RPC=$LOCAL_RPC
echo "================ SET COMMITTEE MIN OPERATORS TO $RPC ================"
forge script \
    script/owner/SetCommitteeMinOperators.s.sol \
    --rpc-url $RPC \
    --legacy \
    --broadcast 