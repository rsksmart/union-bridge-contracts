#!/bin/bash
set -e  # exit on error

RSK_DESTINATION_ADDRESS="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"
REQUEST_PEGIN_TX_HASH="0x2f4d99bc339321df09c32e0011a83ef0be0c7375db767dc3470bc70e1c6e74d7"
PEGIN_SIGNATURE_HASH="0xd03d349e121593bcdd96aab273af54bd73508e4979d0f79d16e0c48ab42ff4ad"
ACCEPT_PEGIN_TX_HASH="0x3f3b22c9d1c2a322e91111b901568e441959bc4137945490e643ee6691968754"
PEGOUT_SIGNATURE_HASH="0x7e00ec037f2ac760a440f781ac4f344bea7c7b3e4869a7793c4c6050c83d9e22"
MNEMONIC_INDEX=0
NONCE="0xf8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000"
TAKE_TXHASH="0x568f1ca77e2ee65f336da9e4aad15526bbf6e17338c4e1baf6e42e2cc188dfa1"

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
bash "$SCRIPT_DIR/operator-take/add-every-operator-take-tx-hash.sh" -a "$ACCEPT_PEGIN_TX_HASH" -t "$TAKE_TXHASH"
bash "$SCRIPT_DIR/signatures/add-every-member-nonce-and-signature.sh" -h "$PEGIN_SIGNATURE_HASH"
bash "$SCRIPT_DIR/accept-pegin.sh" -r "$REQUEST_PEGIN_TX_HASH"
bash "$SCRIPT_DIR/try-pegout.sh"
bash "$SCRIPT_DIR/signatures/add-member-nonce.sh" -m "$MNEMONIC_INDEX" -h "$PEGOUT_SIGNATURE_HASH" -n "$NONCE"
# Advance the time for user take timeout
echo "================ ADVANCE $RPC TIME TO $TIMESTAMP ================"
cast rpc evm_setNextBlockTimestamp $TIMESTAMP --rpc-url $RPC
cast rpc evm_mine --rpc-url $RPC
# Start the operator take flow
bash "$SCRIPT_DIR/operator-take/trigger-operator-take.sh" -p "$PEGOUT_SIGNATURE_HASH"
bash "$SCRIPT_DIR/operator-take/register-operator-take.sh" -a "$ACCEPT_PEGIN_TX_HASH"