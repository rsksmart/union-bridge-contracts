#!/bin/bash

# This script runs the pegin/pegout flow, including:
# 1. Register 10 members and deposit their aggregated key to create a committee and packet
# 2. Registering a request pegin
# 3. Adding every member signature
# 4. Accepting the request pegin

set -e  # exit on error



# Parse args for --alphanet flag
ALPHANET_FLAG=""
RSK_DESTINATION_ADDRESS=""
REQUEST_PEGIN_TXID=""
ACCEPT_PEGIN_TXID=""
while getopts ":a:d:r:-:" opt; do
  case "$opt" in
    a) ACCEPT_PEGIN_TXID="$OPTARG" ;;
    d) RSK_DESTINATION_ADDRESS="$OPTARG" ;;
    r) REQUEST_PEGIN_TXID="$OPTARG" ;;
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

# Enforce required args
if [ -z "$ACCEPT_PEGIN_TXID" ] || [ -z "$RSK_DESTINATION_ADDRESS" ] || [ -z "$REQUEST_PEGIN_TXID" ]; then
  echo "Error: ACCEPT_PEGIN_TXID, RSK_DESTINATION_ADDRESS and REQUEST_PEGIN_TXID are required."
  echo "Usage: $0 -a <accept_pegin_txid> -d <rsk_destination_address> -r <request_pegin_txid>"
  echo ACCEPT_PEGIN_TXID: $ACCEPT_PEGIN_TXID
  echo RSK_DESTINATION_ADDRESS: $RSK_DESTINATION_ADDRESS
  echo REQUEST_PEGIN_TXID: $REQUEST_PEGIN_TXID
  exit 1
fi

# Get the directory where this script is located
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT_DIR="$CURRENT_PATH/.."

echo "================ RUN PEGIN FLOW ================"
echo "=== IS TEST: $IS_TEST ==="

bash "$SCRIPT_DIR/get-temporary-address.sh" $ALPHANET_FLAG

# Request pegin - this reserves a slot in RESERVED state
bash "$SCRIPT_DIR/request-pegin.sh" -a "$RSK_DESTINATION_ADDRESS" $ALPHANET_FLAG

# Add every operator take txid
bash "$SCRIPT_DIR/operator-take/add-every-operator-take-txid.sh" -a "$ACCEPT_PEGIN_TXID" $ALPHANET_FLAG
# add the signatures and nonces for user take
bash "$SCRIPT_DIR/signatures/add-every-member-nonce-and-signature.sh" -h "$ACCEPT_PEGIN_TXID" $ALPHANET_FLAG

# Accept pegin - this fills the reserved slot to FILLED state
bash "$SCRIPT_DIR/accept-pegin.sh" -r "$REQUEST_PEGIN_TXID" $ALPHANET_FLAG

echo "================ PEGIN FLOW COMPLETE ================"