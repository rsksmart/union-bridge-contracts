#!/bin/bash
set -e  # exit on error

RSK_DESTINATION_ADDRESS="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
REQUEST_PEGIN_TXID="0x2f4d99bc339321df09c32e0011a83ef0be0c7375db767dc3470bc70e1c6e74d7"
ACCEPT_PEGIN_TXID="0x0eda936375602f9cb97a435b2402d9ea96ba475de1b2555025d1db2b29e96503"
PEGOUT_TXID="0x2e7cc0e0ee67af68f3d5c3d91e7322d55cf7acce0ba853ff1c3c50eb0fff982e"
MNEMONIC_INDEX=0
NONCE="0xf8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000"
TAKE_TXID="0x568f1ca77e2ee65f336da9e4aad15526bbf6e17338c4e1baf6e42e2cc188dfa1"

# Current Timestamp plus 3 hours
TIMESTAMP=$(($(date +%s) + 3 * 3600))

# Get the directory where this script is located
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT_DIR="$CURRENT_PATH/.."

# set up environment variables
source .env
RPC=$LOCAL_RPC
echo "================ RUN OPERATOR TAKE FLOW ================"

bash "$SCRIPT_DIR/request-pegin.sh" -a "$RSK_DESTINATION_ADDRESS"
bash "$SCRIPT_DIR/operator-take/add-every-operator-take-txid.sh" -a "$ACCEPT_PEGIN_TXID" -t "$TAKE_TXID"
bash "$SCRIPT_DIR/signatures/add-every-member-nonce-and-signature.sh" -h "$ACCEPT_PEGIN_TXID"
bash "$SCRIPT_DIR/accept-pegin.sh" -r "$REQUEST_PEGIN_TXID"
bash "$SCRIPT_DIR/try-pegout.sh"
bash "$SCRIPT_DIR/signatures/add-member-nonce.sh" -m "$MNEMONIC_INDEX" -h "$PEGOUT_TXID" -n "$NONCE"
# Advance the time for user take timeout
echo "================ ADVANCE $RPC TIME TO $TIMESTAMP ================"
cast rpc evm_setNextBlockTimestamp $TIMESTAMP --rpc-url $RPC
cast rpc evm_mine --rpc-url $RPC
# Start the operator take flow
bash "$SCRIPT_DIR/operator-take/trigger-operator-take.sh" -p "$PEGOUT_TXID"
bash "$SCRIPT_DIR/operator-take/register-operator-take.sh" -a "$ACCEPT_PEGIN_TXID"