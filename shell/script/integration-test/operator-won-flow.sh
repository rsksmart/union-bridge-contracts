#!/bin/bash
set -e  # exit on error

RSK_DESTINATION_ADDRESS="0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BD"
REQUEST_PEGIN_TXID="0xf0a9dbb31c82cb5737a9fa1b3c3f784257c249ae087b8f00c6d87e23837345ca"
ACCEPT_PEGIN_TXID="0x7c176a5e8cb3934c1352bfcf979c8359a19d083ef42ed1118ae552a511e8d2bb"
PEGOUT_TXID="0xae3ae334fdd6a0dcc43198e8c4efda2bce75c2469ecb9c53527474fc3f8dbdf2"
MNEMONIC_INDEX=0
NONCE="0xf8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000"

# Current Timestamp plus 6 hours
TIMESTAMP=$(($(date +%s) + 6 * 3600))

# Get the directory where this script is located
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT_DIR="$CURRENT_PATH/.."

# set up environment variables
source .env

# Parse args for --alphanet flag
ALPHANET_FLAG=""
RPC=$LOCAL_RPC
while getopts ":-:" opt; do
  case "$opt" in
    -)
      case "${OPTARG}" in
        alphanet)
          ALPHANET_FLAG="--alphanet"
          RPC=$RSK_ALPHANET_RPC
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

echo "================ RUN OPERATOR TAKE FLOW ================"

bash "$SCRIPT_DIR/request-pegin.sh" -a "$RSK_DESTINATION_ADDRESS" $ALPHANET_FLAG
bash "$SCRIPT_DIR/operator-take/add-every-operator-take-txid.sh" -a "$ACCEPT_PEGIN_TXID" $ALPHANET_FLAG
bash "$SCRIPT_DIR/signatures/add-every-member-nonce-and-signature.sh" -h "$ACCEPT_PEGIN_TXID" $ALPHANET_FLAG
bash "$SCRIPT_DIR/accept-pegin.sh" -r "$REQUEST_PEGIN_TXID" $ALPHANET_FLAG
bash "$SCRIPT_DIR/try-pegout.sh" $ALPHANET_FLAG
bash "$SCRIPT_DIR/signatures/add-member-nonce.sh" -m "$MNEMONIC_INDEX" -h "$PEGOUT_TXID" -n "$NONCE" $ALPHANET_FLAG
# Advance the time for user take timeout
echo "================ ADVANCE $RPC TIME TO $TIMESTAMP ================"
cast rpc evm_setNextBlockTimestamp $TIMESTAMP --rpc-url $RPC
cast rpc evm_mine --rpc-url $RPC
# Start the operator take flow
bash "$SCRIPT_DIR/operator-take/trigger-operator-take.sh" -p "$PEGOUT_TXID" $ALPHANET_FLAG
bash "$SCRIPT_DIR/operator-take/register-operator-won.sh" -a "$ACCEPT_PEGIN_TXID" $ALPHANET_FLAG