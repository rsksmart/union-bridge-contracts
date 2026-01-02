#!/bin/bash

# This script runs the pegin/pegout flow, including:
# 1. Register 10 members and deposit their aggregated key to create a committee and packet
# 2. Registering a request pegin
# 3. Adding every member signature
# 4. Accepting the request pegin
# 5. Registering a pegout request
# 6. Adding every member signature
# 7. Registering the user take pegout

set -e  # exit on error

PEGIN_TXID="0x53afc0118c15081dcfb82692ff3010f25036696388b37b169f68c2348baf2b0e"
PEGOUT_TXID="0x7f199fa320d5e552bd9ef24303d805ea1ff69c8bc23ed5a56e9e8f3fb9c00c0b"

# Slot parameters for monitoring (using defaults from test setup)
STREAM_ID=0
PACKET_NUMBER=0
SLOT_ID=0

# Parse args for --alphanet flag
ALPHANET_FLAG=""
while getopts ":-:" opt; do
  case "$opt" in
    -)
      case "${OPTARG}" in
        alphanet)
          ALPHANET_FLAG="--alphanet"
          ;;
        *)
          echo "Unknown option --${OPTARG}" >&2
          exit 1
          ;;
      esac
      ;;
    *)
      echo "Unknown option -${opt}" >&2
      exit 1
      ;;
  esac
done

# Get the directory where this script is located
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT_DIR="$CURRENT_PATH/.."

bash "$SCRIPT_DIR/integration-test/packet-creation-flow.sh" $ALPHANET_FLAG

echo "================ RUN PEGIN FLOW ================"
bash "$SCRIPT_DIR/get-temporary-address.sh" $ALPHANET_FLAG

# Request pegin - this reserves a slot in RESERVED state
bash "$SCRIPT_DIR/request-pegin.sh" $ALPHANET_FLAG

echo "================ CHECK SLOT STATE AFTER REQUEST ================"
echo "After request pegin, slot should be in RESERVED state:"
bash "$SCRIPT_DIR/get-slot-info.sh" -s "$STREAM_ID" -p "$PACKET_NUMBER" -l "$SLOT_ID" $ALPHANET_FLAG

bash "$SCRIPT_DIR/operator-take/add-every-operator-take-txid.sh" $ALPHANET_FLAG
bash "$SCRIPT_DIR/signatures/add-every-member-nonce-and-signature.sh" -h "$PEGIN_TXID" $ALPHANET_FLAG

# Accept pegin - this fills the reserved slot to FILLED state
bash "$SCRIPT_DIR/accept-pegin.sh" $ALPHANET_FLAG

echo "================ CHECK SLOT STATE AFTER ACCEPT ================"
echo "After accept pegin, slot should be in FILLED state:"
bash "$SCRIPT_DIR/get-slot-info.sh" -s "$STREAM_ID" -p "$PACKET_NUMBER" -l "$SLOT_ID" $ALPHANET_FLAG

echo "================ RUN PEGOUT FLOW ================"
echo "Before pegout, slot should still be in FILLED state:"
bash "$SCRIPT_DIR/get-slot-info.sh" -s "$STREAM_ID" -p "$PACKET_NUMBER" -l "$SLOT_ID" $ALPHANET_FLAG

# Try pegout - this locks the slot to LOCKED state
bash "$SCRIPT_DIR/try-pegout.sh" $ALPHANET_FLAG

echo "================ CHECK SLOT STATE AFTER PEGOUT ================"
echo "After try pegout, slot should be in LOCKED state:"
bash "$SCRIPT_DIR/get-slot-info.sh" -s "$STREAM_ID" -p "$PACKET_NUMBER" -l "$SLOT_ID" $ALPHANET_FLAG

bash "$SCRIPT_DIR/signatures/add-every-member-nonce-and-signature.sh" -h "$PEGOUT_TXID" $ALPHANET_FLAG

# Register user take - this completes the slot to COMPLETED state
bash "$SCRIPT_DIR/register-user-take.sh" $ALPHANET_FLAG

echo "================ CHECK SLOT STATE AFTER USER TAKE ================"
echo "After user take, slot should be in COMPLETED state:"
bash "$SCRIPT_DIR/get-slot-info.sh" -s "$STREAM_ID" -p "$PACKET_NUMBER" -l "$SLOT_ID" $ALPHANET_FLAG

# Note: operator-take-flow.sh is a separate standalone test for operator advancing funds
# It should be run independently, not as part of the main peg-flow
# TODO: Uncomment after fixing. Need to registerAdvanceFunds and ReimbursementKickoff first.
# bash "$SCRIPT_DIR/integration-test/operator-take-flow.sh" $ALPHANET_FLAG

echo "================ PEGIN FLOW COMPLETE ================"
