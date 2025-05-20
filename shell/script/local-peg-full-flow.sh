#!/bin/bash

# This script sets up a local Ethereum node using Anvil, deploy contracts and runs the peg-in/peg-out flow.

# Make sure to kill any existing anvil process
kill -9 $(lsof -ti :8545)

set -e  # exit on error
anvil & # Start anvil in the background

# Wait for anvil to start
while ! nc -z localhost 8545; do
  sleep 1 # wait for anvil to start
done

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$SCRIPT_DIR/deploy/deploy-local.sh"

# This script runs the pegin/pegout flow, including:
# 1. Registering a pegin request
# 2. Accepting the pegin request
# 3. Registering a pegout request
# 4. Adding a member signature

bash "$SCRIPT_DIR/peg-flow.sh"
