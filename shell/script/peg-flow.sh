#!/bin/bash

# This script runs the pegin/pegout flow, including:
# 1. Registering a pegin request
# 2. Accepting the pegin request
# 3. Registering a pegout request
# 4. Adding a member signature

set -e  # exit on error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$SCRIPT_DIR/register-pegin-request.sh"
bash "$SCRIPT_DIR/accept-pegin-request.sh"
bash "$SCRIPT_DIR/register-pegout-request.sh"
bash "$SCRIPT_DIR/add-member-signature.sh"
