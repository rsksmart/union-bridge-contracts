#!/bin/bash

# This script runs the pegin/pegout flow, including:
# 1. Register 10 members and deposit their aggregated key to create a committee and packet
# 2. Registering a pegin request
# 3. Accepting the pegin request
# 4. Registering a pegout request
# 5. Adding every member signature
# 6. Registering the pegout

set -e  # exit on error

PEGOUT_SIGNATURE_HASH="0x84db689c468f3824c4f010331d786d97b59ce5ac15ab69dda529291d9db762d7"
PEGIN_SIGNATURE_HASH="0x5642b8f6a605936eebaac9dcb46687bdf400948285d293283dcb87251aecd55b"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$SCRIPT_DIR/packet-creation-flow.sh"
bash "$SCRIPT_DIR/request-pegin.sh"
bash "$SCRIPT_DIR/add-every-member-nonce-and-signature.sh" -h "$PEGIN_SIGNATURE_HASH"
bash "$SCRIPT_DIR/accept-pegin.sh"
bash "$SCRIPT_DIR/request-pegout.sh"
bash "$SCRIPT_DIR/add-every-member-nonce-and-signature.sh" -h "$PEGOUT_SIGNATURE_HASH"
bash "$SCRIPT_DIR/register-pegout.sh"
