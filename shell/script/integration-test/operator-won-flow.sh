#!/bin/bash

export IS_TEST=true

# This script sets up a local Ethereum node using Anvil, deploy contracts and runs the operator take flow.

# Make sure to kill any existing anvil process
kill -9 $(lsof -ti :8545) 2>/dev/null || true

set -e  # exit on error

# Function to cleanup anvil on exit
cleanup() {
    echo "================ CLEANING UP ================"
    kill -9 $(lsof -ti :8545) 2>/dev/null || true
    echo "Anvil stopped"
}

# Set trap to cleanup on exit
trap cleanup EXIT INT TERM

# Start anvil in the background
anvil > /dev/null &

# Wait for anvil to start
while ! nc -z localhost 8545; do
  sleep 1 # wait for anvil to start
done

echo "================ ANVIL STARTED ================"

# Get the directory where this script is located
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT_DIR="$CURRENT_PATH/.."

# Clean and deploy contracts
bash "$SCRIPT_DIR/integration-test/initial-setup.sh"

# Defaults
RSK_DESTINATION_ADDRESS="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BD"
REQUEST_PEGIN_TXID="0xf0a9dbb31c82cb5737a9fa1b3c3f784257c249ae087b8f00c6d87e23837345ca"
ACCEPT_PEGIN_TXID="0x7c176a5e8cb3934c1352bfcf979c8359a19d083ef42ed1118ae552a511e8d2bb"
PEGOUT_TXID="0xae3ae334fdd6a0dcc43198e8c4efda2bce75c2469ecb9c53527474fc3f8dbdf2"
MNEMONIC_INDEX=0
NONCE="0xf8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000"
# Current Timestamp plus 6 hours
TIMESTAMP=$(($(date +%s) + 6 * 3600))

# set up environment variables
source .env

# Parse args for --alphanet flag
ALPHANET_FLAG=""
RPC=$LOCAL_RPC
while getopts ":-:" opt; do
  case "$opt" in
    -)
      case "${OPTARG}" in
        alphanet)
          ALPHANET_FLAG="--alphanet"
          RPC=$RSK_ALPHANET_RPC
          ;;
        *)
          echo "Unknown option --${OPTARG}" >&2
          exit 1
          ;;
      esac
      ;;
    *)
      echo "Unknown option -${opt}" >&2
      exit 1
      ;;
  esac
done

bash "$SCRIPT_DIR/integration-test/packet-creation-flow.sh" $ALPHANET_FLAG

bash "$SCRIPT_DIR/integration-test/pegin-flow.sh" -a "$ACCEPT_PEGIN_TXID" -d "$RSK_DESTINATION_ADDRESS" -r "$REQUEST_PEGIN_TXID" $ALPHANET_FLAG

echo "================ RUN OPERATOR WON FLOW ================"
bash "$SCRIPT_DIR/try-pegout.sh" $ALPHANET_FLAG
#Add only one member nonce and signature for the pegout
bash "$SCRIPT_DIR/signatures/add-member-nonce.sh" -m "$MNEMONIC_INDEX" -h "$PEGOUT_TXID" -n "$NONCE" $ALPHANET_FLAG
# Advance the time for user take timeout
echo "================ ADVANCE $RPC TIME TO $TIMESTAMP ================"
cast rpc evm_setNextBlockTimestamp $TIMESTAMP --rpc-url $RPC
cast rpc evm_mine --rpc-url $RPC
# Start the operator take flow (advance funds and reimbursement kickoff)
bash "$SCRIPT_DIR/operator-take/trigger-operator-take.sh" -h "$PEGOUT_TXID" $ALPHANET_FLAG
# Register operator won - (this challenges the reimbursement kickoff, then reveals the input and finally registers the operator won)
bash "$SCRIPT_DIR/operator-take/register-operator-won.sh" -a "$ACCEPT_PEGIN_TXID" $ALPHANET_FLAG