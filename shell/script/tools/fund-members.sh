#!/bin/bash
set -e

# Fund all 10 mnemonic addresses for testing
# Usage: ./fund-members.sh -f <funder_private_key> -a <amount_per_member> [--alphanet]

CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../.."

source .env
RPC=$LOCAL_RPC

# Default amount per member (0.05 RBTC)
AMOUNT_PER_MEMBER="0.05ether"
FUNDER_PRIVATE_KEY=""

# Parse args
while getopts "f:a:-:" opt; do
  case "$opt" in
    f) FUNDER_PRIVATE_KEY=$OPTARG ;;
    a) AMOUNT_PER_MEMBER=$OPTARG ;;
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
      echo "Usage: $0 -f <funder_private_key> [-a <amount_per_member>] [--alphanet]"
      echo "Example: $0 -f 0x123... -a 0.1ether --alphanet"
      exit 1
      ;;
  esac
done

if [ -z "$FUNDER_PRIVATE_KEY" ]; then
    echo "Error: Funder private key is required"
    echo "Usage: $0 -f <funder_private_key> [-a <amount_per_member>] [--alphanet]"
    exit 1
fi

echo "================ FUNDING 10 MEMBERS ================"
echo "RPC: $RPC"
echo "Amount per member: $AMOUNT_PER_MEMBER"
echo "=================================================================="

# Fund each member (indices 0-9)
for i in $(seq 0 $MAX_MNEMONIC_INDEX); do
    # Get member address from mnemonic at index i
    MEMBER_ADDRESS=$(cast wallet address --mnemonic "$MNEMONIC" --mnemonic-index $i)

    echo "Funding member $i: $MEMBER_ADDRESS"

    # Send funds to member
    cast send $MEMBER_ADDRESS \
        --value $AMOUNT_PER_MEMBER \
        --private-key $FUNDER_PRIVATE_KEY \
        --rpc-url $RPC \
        --legacy

    # Check balance to confirm
    BALANCE=$(cast balance $MEMBER_ADDRESS --rpc-url $RPC --ether)
    echo "  Balance after funding: $BALANCE RBTC"
    echo ""
done

echo "================ FUNDING COMPLETE ================"
echo "All 10 members have been funded with $AMOUNT_PER_MEMBER each"

# Show summary
echo ""
echo "================ MEMBER SUMMARY ================"
for i in $(seq 0 $MAX_MNEMONIC_INDEX); do
    MEMBER_ADDRESS=$(cast wallet address --mnemonic "$MNEMONIC" --mnemonic-index $i)
    BALANCE=$(cast balance $MEMBER_ADDRESS --rpc-url $RPC --ether)
    echo "Member $i: $MEMBER_ADDRESS - $BALANCE RBTC"
done