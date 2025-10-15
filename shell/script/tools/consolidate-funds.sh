#!/bin/bash
set -e

# Consolidate funds from all mnemonic addresses to index 0
# If any address has more than 0.05 RBTC, send the excess to index 0
# Usage: ./consolidate-funds.sh [--alphanet]

CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../.."

source .env
RPC=$LOCAL_RPC

# Threshold in RBTC - keep this much in each account
THRESHOLD="0.05"

# Parse args
while getopts ":-:" opt; do
  case "$opt" in
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
    \?)
      echo "Usage: $0 [--alphanet]"
      exit 1
      ;;
  esac
done

echo "================ CONSOLIDATING FUNDS TO INDEX 0 ================"
echo "RPC: $RPC"
echo "Threshold: $THRESHOLD RBTC (keeping this much in each account)"
echo "=================================================================="

# Get index 0 address (recipient)
RECIPIENT_ADDRESS=$(cast wallet address --mnemonic "$MNEMONIC" --mnemonic-index 0)
echo "Recipient (index 0): $RECIPIENT_ADDRESS"
echo ""

# Consolidate from indices 1-9
for i in $(seq 1 $MAX_MNEMONIC_INDEX); do
    MEMBER_ADDRESS=$(cast wallet address --mnemonic "$MNEMONIC" --mnemonic-index $i)
    BALANCE=$(cast balance $MEMBER_ADDRESS --rpc-url $RPC --ether)

    echo "Checking member $i: $MEMBER_ADDRESS"
    echo "  Current balance: $BALANCE RBTC"

    # Compare balances using bc
    SHOULD_SEND=$(echo "$BALANCE > $THRESHOLD" | bc -l)

    if [ "$SHOULD_SEND" -eq 1 ]; then
        # Calculate amount to send (balance - threshold - gas buffer)
        # Keep 0.05 + small gas buffer (0.001)
        GAS_BUFFER="0.001"
        KEEP_AMOUNT=$(echo "$THRESHOLD + $GAS_BUFFER" | bc -l)
        # Ensure leading zero in result
        SEND_AMOUNT=$(echo "scale=18; $BALANCE - $KEEP_AMOUNT" | bc -l | sed 's/^\./0./')

        # Only send if amount is positive and significant (> 0.001)
        IS_SIGNIFICANT=$(echo "$SEND_AMOUNT > 0.001" | bc -l)

        if [ "$IS_SIGNIFICANT" -eq 1 ]; then
            echo "  Sending $SEND_AMOUNT RBTC to index 0..."

            # Get private key for this member
            MEMBER_PRIVATE_KEY=$(cast wallet private-key --mnemonic "$MNEMONIC" --mnemonic-index $i)

            # Send funds
            cast send $RECIPIENT_ADDRESS \
                --value "${SEND_AMOUNT}ether" \
                --private-key $MEMBER_PRIVATE_KEY \
                --rpc-url $RPC \
                --legacy

            # Check new balance
            NEW_BALANCE=$(cast balance $MEMBER_ADDRESS --rpc-url $RPC --ether)
            echo "  New balance: $NEW_BALANCE RBTC"
        else
            echo "  Amount too small to send ($SEND_AMOUNT RBTC), skipping"
        fi
    else
        echo "  Balance below threshold, skipping"
    fi
    echo ""
done

echo "================ CONSOLIDATION COMPLETE ================"
echo ""
echo "================ FINAL BALANCES ================"
for i in $(seq 0 $MAX_MNEMONIC_INDEX); do
    MEMBER_ADDRESS=$(cast wallet address --mnemonic "$MNEMONIC" --mnemonic-index $i)
    BALANCE=$(cast balance $MEMBER_ADDRESS --rpc-url $RPC --ether)
    echo "Member $i: $MEMBER_ADDRESS - $BALANCE RBTC"
done
