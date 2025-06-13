#!/bin/bash

# This script runs the pegin/pegout flow, including:
# 1. Register 10 members and deposit their aggregated key to create a committee and packet
# 2. Registering a pegin request
# 3. Accepting the pegin request
# 4. Registering a pegout request
# 5. Adding every member signature
# 6. Registering the pegout

set -e  # exit on error

PEGOUT_SIGNATURE_HASH="0xbdbcc0e498ff3efd9332048959b808326e6361ba820aabdde997c49b699e8b20"
PEGIN_SIGNATURE_HASH="0xfba8ece80878b0fc5faab104b2df2fd6b1eb272c13d5146cef1b998ca3f261eb"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$SCRIPT_DIR/packet-creation-flow.sh"
bash "$SCRIPT_DIR/request-pegin.sh"
bash "$SCRIPT_DIR/add-every-member-nonce-and-signature.sh" -h "$PEGIN_SIGNATURE_HASH"
bash "$SCRIPT_DIR/accept-pegin.sh"
bash "$SCRIPT_DIR/request-pegout.sh"
bash "$SCRIPT_DIR/add-every-member-nonce-and-signature.sh" -h "$PEGOUT_SIGNATURE_HASH"
bash "$SCRIPT_DIR/register-pegout.sh"
