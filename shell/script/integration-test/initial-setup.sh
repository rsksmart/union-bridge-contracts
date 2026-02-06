#!/bin/bash

# Get the directory where this script is located
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT_DIR="$CURRENT_PATH/.."

# Clean and deploy contracts
bash "$SCRIPT_DIR/deploy/deploy-local.sh"

echo "================ CONTRACTS DEPLOYED ================"

# Fund the bridge mock with RBTC for pegin operations
bash "$SCRIPT_DIR/fund-bridge.sh"

echo "================ BRIDGE FUNDED ================"