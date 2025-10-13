# Go to project root
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$CURRENT_PATH/../../.."

# Load environment variables
source .env
RPC=$LOCAL_RPC

# Parse arguments
while getopts "m:h:s:-:" opt; do
  case "$opt" in
    m) MNEMONIC_INDEX=$OPTARG ;;
    h) TXID=$OPTARG ;;
    s) SIGNATURE=$OPTARG ;;
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
      echo "Usage: $0 -m <mnemonic_index> -h <signature_hash> -s <signature> [--alphanet]"
      exit 1
      ;;
  esac
done

# Validate inputs
if [ -z "$MNEMONIC_INDEX" ] || [ -z "$TXID" ] || [ -z "$SIGNATURE" ]; then
  echo "Error: All three arguments -m, -h, and -s are required."
  exit 1
fi

# Run Forge script
#echo "================ ADD MEMBER SIGNATURE TO $RPC ================"
forge script \
  script/AddMemberSignature.s.sol \
  --sig "run(uint16,bytes32,bytes32)" \
  "$MNEMONIC_INDEX" "$TXID" "$SIGNATURE" \
  --rpc-url "$RPC" \
  --legacy \
  --broadcast \