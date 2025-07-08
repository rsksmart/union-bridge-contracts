#!/bin/bash

# This script runs the pegin/pegout flow, including:
# 1. Register 10 members and deposit their aggregated key to create a committee and packet
# 2. Registering a pegin request
# 3. Adding every member signature
# 4. Accepting the pegin request
# 5. Registering a pegout request
# 6. Adding every member signature
# 7. Registering the user take pegout

set -e  # exit on error

PEGIN_SIGNATURE_HASH="0x5642b8f6a605936eebaac9dcb46687bdf400948285d293283dcb87251aecd55b"
PEGOUT_SIGNATURE_HASH="0x84db689c468f3824c4f010331d786d97b59ce5ac15ab69dda529291d9db762d7"

# Get the directory where this script is located
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT_DIR="$CURRENT_PATH/.."

bash "$SCRIPT_DIR/integration-test/packet-creation-flow.sh"
echo "================ RUN PEGIN FLOW ================"
bash "$SCRIPT_DIR/get-temporary-address.sh"
bash "$SCRIPT_DIR/request-pegin.sh"
bash "$SCRIPT_DIR/signatures/add-every-member-nonce-and-signature.sh" -h "$PEGIN_SIGNATURE_HASH"
bash "$SCRIPT_DIR/accept-pegin.sh"
echo "================ RUN PEGOUT FLOW ================"
bash "$SCRIPT_DIR/try-pegout.sh"
bash "$SCRIPT_DIR/signatures/add-every-member-nonce-and-signature.sh" -h "$PEGOUT_SIGNATURE_HASH"
bash "$SCRIPT_DIR/register-user-take.sh"
bash "$SCRIPT_DIR/integration-test/operator-take-flow.sh"
