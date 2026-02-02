#!/bin/bash
set -e

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# set up environment variables
source .env

# Set network-specific variables
export NETWORK=regtest
export RPC=$RSK_REGTEST_RPC
export CHAIN_ID=33

# Disable verification for regtest
SHOULD_VERIFY=false

# Call the common deployment script with no verification
"$CURRENT_PATH/deploy-common.sh" $SHOULD_VERIFY
