#!/bin/bash

export IS_TEST=true

# This script sets up a local Ethereum node using Anvil, deploy contracts and runs the peg-in/peg-out flow.

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


# This script runs the pegin/pegout flow, including:
# 1. Register 10 members and deposit their aggregated key to create a committee and packet
# 2. Registering a request pegin
# 3. Adding every member signature
# 4. Accepting the request pegin
# 5. Registering a pegout request
# 6. Adding every member signature
# 7. Registering the user take pegout

RSK_DESTINATION_ADDRESS="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
REQUEST_PEGIN_TXID="0x0f52a17b791cf01a50af91789469afb496087fb45850b4e8b43f756ad925ad20"
ACCEPT_PEGIN_TXID="0x8c7ac99690001ba50f5ffc9b774fa96fdcf1b391a8e62b7fb89c415886e8b9eb"
PEGOUT_TXID="0xe79b796c054aee1c83dd576391a1c9d007db6f5d835219b5d337ba439c86078f"

# Parse args for --alphanet flag
ALPHANET_FLAG=""
while getopts ":-:" opt; do
  case "$opt" in
    -)
      case "${OPTARG}" in
        alphanet)
          ALPHANET_FLAG="--alphanet"
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

bash "$SCRIPT_DIR/integration-test/pegin-flow.sh" -a "$ACCEPT_PEGIN_TXID" -d "$RSK_DESTINATION_ADDRESS" -r "$REQUEST_PEGIN_TXID"  $ALPHANET_FLAG

echo "================ RUN USER TAKE FLOW ================"
# Try pegout - this locks the slot to LOCKED state
bash "$SCRIPT_DIR/try-pegout.sh" $ALPHANET_FLAG

# Add every member nonce and signature for the pegout
bash "$SCRIPT_DIR/signatures/add-every-member-nonce-and-signature.sh" -h "$PEGOUT_TXID" $ALPHANET_FLAG

# Register user take - this completes the slot to COMPLETED state
bash "$SCRIPT_DIR/register-user-take.sh" $ALPHANET_FLAG

echo "================ USER TAKE FLOW COMPLETE ================"

