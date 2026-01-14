

#!/bin/bash

# This script sets up a local Ethereum node using Anvil, deploys contracts and demonstrates the blocked slot functionality:
# 1. Sets up anvil and deploys contracts
# 2. Sets up a committee and packet
# 3. Requests a pegin (slot goes to RESERVED state)
# 4. Checks slot state (should be RESERVED)
# 5. Blocks the reserved slot (slot goes to BLOCKED state)
# 6. Checks slot state again (should be BLOCKED)

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

echo "================ REJECT PEGIN FLOW ================"
echo "This flow shows how to reject a pegin"

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

# REQUEST PEGIN TXID FOR REJECT PEGIN
REQUEST_PEGIN_TXID="0x0f52a17b791cf01a50af91789469afb496087fb45850b4e8b43f756ad925ad20"

# Setup committee and packet
bash "$SCRIPT_DIR/integration-test/packet-creation-flow.sh"

echo "================ STEP 1: REQUEST PEGIN ================"
bash "$SCRIPT_DIR/request-pegin.sh"

echo "================ STEP 2: REJECT PEGIN - BLOCK THE SLOT ================"
bash "$SCRIPT_DIR/reject-pegin.sh" -r "$REQUEST_PEGIN_TXID"

echo "================ REJECT PEGIN FLOW COMPLETE ================"
