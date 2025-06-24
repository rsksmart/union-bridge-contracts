# Go to project root
CURRENT_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$CURRENT_PATH/../../.."

# Load environment variables
source .env
RPC=$LOCAL_RPC

# Parse arguments
while getopts "m:h:n:" opt; do
  case "$opt" in
    m) MNEMONIC_INDEX=$OPTARG ;;
    h) SIGNATURE_HASH=$OPTARG ;;
    n) NONCE=$OPTARG ;;
    \?)
      echo "Usage: $0 -m <mnemonic_index> -h <signature_hash> -n <nonce>"
      exit 1
      ;;
  esac
done

# Validate inputs
if [ -z "$MNEMONIC_INDEX" ] || [ -z "$SIGNATURE_HASH" ] || [ -z "$NONCE" ]; then
  echo "Error: All three arguments -m, -h, and -n are required."
  exit 1
fi

# Run Forge script
echo "================ ADD MEMBER NONCE TO $RPC ================"
forge script \
  script/AddMemberNonce.s.sol \
  --sig "run(uint16,bytes32,bytes)" \
  "$MNEMONIC_INDEX" "$SIGNATURE_HASH" "$NONCE" \
  --rpc-url "$RPC" \
  --legacy \
  --broadcast \