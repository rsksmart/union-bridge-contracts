#!/bin/bash

# This script runs the packet creation flow, including:
# 1. Applying members to a stream
# 2. Which triggers the creation of a pending committee
# 3. Depositing member info for each member of the committee
# 4. Which in turn triggers the completion of the creation of the committee and a packet with it


set -e  # exit on error
# set up environment variables
source .env

# Get the directory where this script is located
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPT_DIR="$CURRENT_PATH/.."

# Default values
OPERATOR_AMOUNT=3
WATCHTOWER_AMOUNT=7
STREAM=0
ALPHANET_FLAG=""

# Parse optional args
while getopts "o:w:s:-:" opt; do
  case "$opt" in
    o) OPERATOR_AMOUNT=$OPTARG ;;
    w) WATCHTOWER_AMOUNT=$OPTARG ;;
    s) STREAM=$OPTARG ;;
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
    \?)
      echo "Usage: $0 [-o operator_amount] [-w watchtower_amount] [-s stream_index] [--alphanet]"
      exit 1
      ;;
  esac
done

TOTAL=$((OPERATOR_AMOUNT + WATCHTOWER_AMOUNT))

# Enforce constraints
if [ "$TOTAL" -ne $((MAX_MNEMONIC_INDEX + 1)) ]; then
  echo "Error: Total number of members must be exactly 10 (you passed $TOTAL)."
  exit 1
fi

if [ "$OPERATOR_AMOUNT" -lt 3 ]; then
  echo "Error: Must have at least 3 operators (you passed $OPERATOR_AMOUNT)."
  exit 1
fi

if [ "$WATCHTOWER_AMOUNT" -lt 3 ]; then
  echo "Error: Must have at least 3 watchtowers (you passed $WATCHTOWER_AMOUNT)."
  exit 1
fi

if [ "$STREAM" -gt 4 ]; then
  echo "Error: Stream index must be 0–4 (you passed $STREAM)."
  exit 1
fi

echo "=== APPLYING $OPERATOR_AMOUNT OPERATORS AND $WATCHTOWER_AMOUNT WATCHTOWERS TO STREAM $STREAM ==="

# Apply to stream
for ((i=0; i<=MAX_MNEMONIC_INDEX; i++)); do
  if [ "$i" -lt "$OPERATOR_AMOUNT" ]; then
    ROLE=1  # Operator
  else
    ROLE=2  # Watchtower
  fi
  bash "$SCRIPT_DIR/apply-to-stream.sh" -m "$i" -s "$STREAM" -r "$ROLE" $ALPHANET_FLAG
done

# Check if COMMITTEE_PK is defined in the environment
if [ -z "$COMMITTEE_PK" ]; then
  echo "Error: COMMITTEE_PK is not defined in the environment."
  exit 1
fi

for ((i=0; i<=MAX_MNEMONIC_INDEX; i++)); do
  bash "$SCRIPT_DIR/deposit-communication-data.sh" -m "$i" -s "$STREAM" $ALPHANET_FLAG
done

for ((i=0; i<=MAX_MNEMONIC_INDEX; i++)); do
  bash "$SCRIPT_DIR/get-communication-data-for-one-member.sh" -m "$i" -s "$STREAM" $ALPHANET_FLAG
done

for ((i=0; i<=MAX_MNEMONIC_INDEX; i++)); do
  bash "$SCRIPT_DIR/deposit-aggregated-key.sh" -m "$i" -s "$STREAM" -p "$COMMITTEE_PK" $ALPHANET_FLAG
done