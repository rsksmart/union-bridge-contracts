#!/bin/bash

# Script to get slot information including state and details
# Usage: ./get-slot-info.sh -s <stream_id> -p <packet_number> -l <slot_id>

# we go to the root of the project to avoid relative path issues
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# Defaults
STREAM_ID=""
PACKET_NUMBER=""
SLOT_ID=""

# set up environment variables
source .env
RPC=$LOCAL_RPC

# Parse args
while getopts ":s:p:l:-:" opt; do
  case "$opt" in
    s) STREAM_ID="$OPTARG" ;;
    p) PACKET_NUMBER="$OPTARG" ;;
    l) SLOT_ID="$OPTARG" ;;
    -)
      case "${OPTARG}" in
        alphanet)
          RPC=$RSK_ALPHANET_RPC
          export NETWORK=alphanet
          ;;
        *)
          echo "Unknown option --${OPTARG}"
          exit 1
          ;;
      esac
      ;;
    *)
      echo "Usage: $0 -s <stream_id> -p <packet_number> -l <slot_id> [--alphanet]"
      echo "Example: $0 -s 1 -p 0 -l 0"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [ -z "$STREAM_ID" ] || [ -z "$PACKET_NUMBER" ] || [ -z "$SLOT_ID" ]; then
    echo "Error: All parameters are required"
    echo "Usage: $0 -s <stream_id> -p <packet_number> -l <slot_id>"
    exit 1
fi

echo "================ GET SLOT INFO FROM $RPC ================"
echo "Stream ID: $STREAM_ID, Packet: $PACKET_NUMBER, Slot: $SLOT_ID"

forge script \
    script/tools/GetSlotInfo.s.sol \
    --sig "run(uint64,uint64,uint64)" \
    "$STREAM_ID" "$PACKET_NUMBER" "$SLOT_ID" \
    --rpc-url $RPC \
    --legacy