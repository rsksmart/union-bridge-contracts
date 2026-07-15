#!/bin/bash

# This script runs the packet creation flow, including:
# 1. Whitelisting addresses that will apply to be members
# 2. Applying members to a stream
# 3. Which triggers the creation of a pending committee
# 4. Depositing member info for each member of the committee
# 5. Which in turn triggers the completion of the creation of the committee and a packet with it


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
COMMITTEE_TAKE_PUBKEY=0x02d1cfc2049322ff6ba3a88c6e17c6622308f0fb1d2910ffadb309e4116358723d
COMMITTEE_DISPUTE_PUBKEY=0x02e2dfc3050433ff7cb4b99d7f18d7733319f1fc2e4020ffbcc410f5227469834e


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

# Whitelist the addresses before applying to stream
for ((i=0; i<=MAX_MNEMONIC_INDEX; i++)); do
  bash "$SCRIPT_DIR/whitelist-address.sh" -m "$i"
done

# Apply to stream
for ((i=0; i<=MAX_MNEMONIC_INDEX; i++)); do
  if [ "$i" -lt "$OPERATOR_AMOUNT" ]; then
    ROLE=1  # Operator
  else
    ROLE=2  # Watchtower
  fi
  bash "$SCRIPT_DIR/apply-to-stream.sh" -m "$i" -s "$STREAM" -r "$ROLE" $ALPHANET_FLAG
done

for ((i=0; i<=MAX_MNEMONIC_INDEX; i++)); do
  bash "$SCRIPT_DIR/deposit-communication-data.sh" -m "$i" -s "$STREAM" $ALPHANET_FLAG
done

for ((i=0; i<=MAX_MNEMONIC_INDEX; i++)); do
  bash "$SCRIPT_DIR/get-communication-data-for-one-member.sh" -m "$i" -s "$STREAM" $ALPHANET_FLAG
done

for ((i=0; i<=MAX_MNEMONIC_INDEX; i++)); do
  bash "$SCRIPT_DIR/deposit-aggregated-keys.sh" -m "$i" -s "$STREAM" -t "$COMMITTEE_TAKE_PUBKEY" -d "$COMMITTEE_DISPUTE_PUBKEY" $ALPHANET_FLAG
done