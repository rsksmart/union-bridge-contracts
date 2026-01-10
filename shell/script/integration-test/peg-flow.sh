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

PEGIN_TXID="0x57450e6c6141e63115cf56fc9fd8c29e20792a8c488c3d9e2bd99edac6496ffc"
PEGOUT_TXID="0xa1fcb1ea38e5679173216935c3b8325ffbcc0c4c6c6c81f409b7584361a6ac7b"

# Slot parameters for monitoring (using defaults from test setup)
STREAM_ID=0
PACKET_NUMBER=0
SLOT_ID=0

# Get the directory where this script is located
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT_DIR="$CURRENT_PATH/.."

bash "$SCRIPT_DIR/integration-test/packet-creation-flow.sh"

echo "================ RUN PEGIN FLOW ================"
echo "=== IS TEST: $IS_TEST ==="

bash "$SCRIPT_DIR/get-temporary-address.sh"

# Request pegin - this reserves a slot in RESERVED state
bash "$SCRIPT_DIR/request-pegin.sh"

echo "================ CHECK SLOT STATE AFTER REQUEST ================"
echo "After request pegin, slot should be in RESERVED state:"
bash "$SCRIPT_DIR/get-slot-info.sh" -s "$STREAM_ID" -p "$PACKET_NUMBER" -l "$SLOT_ID"

bash "$SCRIPT_DIR/operator-take/add-every-operator-take-txid.sh"
bash "$SCRIPT_DIR/signatures/add-every-member-nonce-and-signature.sh" -h "$PEGIN_TXID"

# Accept pegin - this fills the reserved slot to FILLED state
bash "$SCRIPT_DIR/accept-pegin.sh"

echo "================ CHECK SLOT STATE AFTER ACCEPT ================"
echo "After accept pegin, slot should be in FILLED state:"
bash "$SCRIPT_DIR/get-slot-info.sh" -s "$STREAM_ID" -p "$PACKET_NUMBER" -l "$SLOT_ID"

echo "================ RUN PEGOUT FLOW ================"
echo "Before pegout, slot should still be in FILLED state:"
bash "$SCRIPT_DIR/get-slot-info.sh" -s "$STREAM_ID" -p "$PACKET_NUMBER" -l "$SLOT_ID"

# Try pegout - this locks the slot to LOCKED state
bash "$SCRIPT_DIR/try-pegout.sh"

echo "================ CHECK SLOT STATE AFTER PEGOUT ================"
echo "After try pegout, slot should be in LOCKED state:"
bash "$SCRIPT_DIR/get-slot-info.sh" -s "$STREAM_ID" -p "$PACKET_NUMBER" -l "$SLOT_ID"

bash "$SCRIPT_DIR/signatures/add-every-member-nonce-and-signature.sh" -h "$PEGOUT_TXID"

# Register user take - this completes the slot to COMPLETED state
bash "$SCRIPT_DIR/register-user-take.sh"

echo "================ CHECK SLOT STATE AFTER USER TAKE ================"
echo "After user take, slot should be in COMPLETED state:"
bash "$SCRIPT_DIR/get-slot-info.sh" -s "$STREAM_ID" -p "$PACKET_NUMBER" -l "$SLOT_ID"

bash "$SCRIPT_DIR/integration-test/operator-take-flow.sh"

echo "================ PEGIN FLOW COMPLETE ================"
