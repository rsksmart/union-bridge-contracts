#!/bin/bash

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

anvil > /dev/null & # Start anvil in the background send stdout to /dev/null

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

# Fund the bridge mock with RBTC for pegin operations
bash "$SCRIPT_DIR/fund-bridge.sh"

echo "================ BRIDGE FUNDED ================"

# This script runs the pegin/pegout flow, including:
# 1. Register 10 members and deposit their aggregated key to create a committee and packet
# 2. Registering a pegin request
# 3. Accepting the pegin request
# 4. Registering a pegout request
# 5. Adding every member signature
# 6. Registering the pegout

bash "$SCRIPT_DIR/integration-test/peg-flow.sh"

echo "================ LOCAL PEG FULL FLOW COMPLETE ================"
