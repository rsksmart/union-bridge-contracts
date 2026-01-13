#!/bin/bash

# This script demonstrates the user reimbursement flow:
# 1. Sets up anvil and deploys contracts
# 2. Sets up a committee and packet
# 3. Requests a pegin (slot goes to RESERVED state)
# 4. Advances Bitcoin blocks past the timelock period
# 5. Registers user reimbursement (slot goes to BLOCKED state)
# 6. Verifies the final state

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

echo "================ USER REIMBURSEMENT DEMONSTRATION ================"
echo "This demo shows how users can reclaim their BTC after timelock expiry"

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
forge clean
bash "$SCRIPT_DIR/deploy/deploy-local.sh"

echo "================ CONTRACTS DEPLOYED ================"

# Slot parameters for monitoring
STREAM_ID=0
PACKET_NUMBER=0
SLOT_ID=0

# Setup committee and packet
bash "$SCRIPT_DIR/integration-test/packet-creation-flow.sh"

echo "================ STEP 1: REQUEST PEGIN ================"
bash "$SCRIPT_DIR/get-temporary-address.sh"
bash "$SCRIPT_DIR/request-pegin.sh"

echo "================ STEP 2: CHECK SLOT STATE (SHOULD BE RESERVED) ================"
echo "After request pegin, slot should be in RESERVED state:"
bash "$SCRIPT_DIR/get-slot-info.sh" -s "$STREAM_ID" -p "$PACKET_NUMBER" -l "$SLOT_ID"

# Use the default request pegin txid RequestPegin.s.sol
REQUEST_PEGIN_TXID="0x0f1c151f3fb74f0020f06c40975e7d1dceb12162666bfdee42c10caf6f8aecba"

echo "================ STEP 3: ADVANCE BITCOIN BLOCKS PAST TIMELOCK ================"
echo "Advancing blocks to simulate timelock expiry..."

# Advance by 1 block to pass the timelock period
bash "$SCRIPT_DIR/advance-bitcoin-blocks.sh" -b 1

echo "Bitcoin blocks advanced. Timelock should now be expired."

echo "================ STEP 4: REGISTER USER REIMBURSEMENT ================"
bash "$SCRIPT_DIR/user-reimbursement.sh" -r "$REQUEST_PEGIN_TXID"

echo "================ STEP 5: CHECK SLOT STATE (SHOULD BE BLOCKED) ================"
echo "After user reimbursement, slot should be in BLOCKED state:"
bash "$SCRIPT_DIR/get-slot-info.sh" -s "$STREAM_ID" -p "$PACKET_NUMBER" -l "$SLOT_ID"

echo "================ USER REIMBURSEMENT DEMO COMPLETE ================"
