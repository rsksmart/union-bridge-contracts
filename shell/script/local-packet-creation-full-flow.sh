#!/bin/bash

# This script sets up a local Ethereum node using Anvil, deploy contracts and runs the peg-in/peg-out flow.

# Make sure to kill any existing anvil process
kill -9 $(lsof -ti :8545)

set -e  # exit on error
anvil > /dev/null & # Start anvil in the background send stdout to /dev/null

# Wait for anvil to start
while ! nc -z localhost 8545; do
  sleep 1 # wait for anvil to start
done

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$SCRIPT_DIR/deploy/deploy-local.sh"

# This script runs the packet creation flow, including:
# 1. Applying members to a stream
# 2. Which triggers the creation of a pending committee
# 3. Depositing member info for each member of the committee
# 4. Which in turn triggers the completion of the creation of the committee and a packet with it

bash "$SCRIPT_DIR/packet-creation-flow.sh"

# Kill any used anvil process
kill -9 $(lsof -ti :8545)
