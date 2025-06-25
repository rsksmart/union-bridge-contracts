#!/bin/sh
echo "================ SIMULATE DEPLOY ================"
# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# openzeppelin-foundry-upgrades requires a clean build
bash shell/clean-build.sh
# remove dry runs as we have one per simulation
rm -rf broadcast/DeployScript.s.sol/31/dry-run
rm -rf cache/DeployScript.s.sol/31/dry-run
# set up environment variables
source .env
# simulate deploy
# we use fork block number 6438663 because we are certain that in this block
# all the wallets we use have enough RSK to pay for the transactions that happen during the simulation of the deployment
# the used wallets are the ones from the mnemonic in the .env file (which are the same ones used by anvil)
forge script script/deploy/DeployScript.s.sol \
    --rpc-url $RSK_TESTNET_RPC \
    --fork-block-number 6438663 \
    --legacy \
    -vvv