#!/bin/bash
# Batch contract verification functions
# These functions verify all implementation and proxy contracts from a broadcast file

# Source configuration and individual verification functions
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$CURRENT_PATH/verify-config.sh"
source "$CURRENT_PATH/verify-functions.sh"

# Build implementation address -> contract name map
build_impl_map() {
    local broadcast_file="$1"
    jq -r '.transactions[] | 
        select(.transactionType == "CREATE" and .contractName != "ERC1967Proxy") | 
        "\(.contractAddress | ascii_downcase),\(.contractName)"' "$broadcast_file"
}

# Verify all implementation contracts
verify_all_implementations() {
    local broadcast_file="$1"
    local chain_id="$2"
    local verifier="$3"
    local verifier_url="$4"
    
    echo "STEP 1: VERIFYING IMPLEMENTATION CONTRACTS"
    echo ""
    
    jq -r '.transactions[] | 
        select(.transactionType == "CREATE" and .contractName != "ERC1967Proxy") | 
        "\(.contractName),\(.contractAddress)"' "$broadcast_file" | \
    while IFS=',' read -r contract_name contract_addr; do
        verify_implementation "$contract_name" "$contract_addr" "$chain_id" "$verifier" "$verifier_url"
    done
}

# Verify all proxy contracts
verify_all_proxies() {
    local broadcast_file="$1"
    local impl_map="$2"
    local chain_id="$3"
    local verifier="$4"
    local verifier_url="$5"
    
    echo "STEP 2: VERIFYING PROXY CONTRACTS"
    echo ""
    
    jq -r '.transactions[] | 
        select(.contractName == "ERC1967Proxy" and .transactionType == "CREATE") | 
        "\(.contractAddress),\(.arguments[0])"' "$broadcast_file" | \
    while IFS=',' read -r proxy_addr impl_addr; do
        local contract_name=$(echo "$impl_map" | grep "^$(echo "$impl_addr" | tr '[:upper:]' '[:lower:]')," | cut -d',' -f2)
        
        if [ -n "$contract_name" ]; then
            verify_proxy "$contract_name" "$proxy_addr" "$chain_id" "$verifier" "$verifier_url" "$broadcast_file"
        else
            echo "  ⚠️  Warning: Could not find contract name for proxy $proxy_addr (impl: $impl_addr)"
        fi
    done
}

# Main verification function that handles all the common logic
verify_all_contracts() {
    local verifier="$1"        # Verifier type: "blockscout" or "custom"
    local api_url="$2"        # API URL for the verifier
    local explorer_url="$3"   # Explorer URL for viewing contracts
    local title="$4"          # Title for the verification output
    local chain_id="$5"       # Chain ID (30 for mainnet, 31 for testnet, etc.)
    local broadcast_file="$6" # Optional broadcast file path
    
    # Set default broadcast file if not provided
    if [ -z "$broadcast_file" ]; then
        broadcast_file="$PROJECT_ROOT/broadcast/DeployScript.s.sol/$chain_id/run-latest.json"
    fi
    
    # Validate broadcast file
    if [ ! -f "$broadcast_file" ]; then
        echo "Error: Broadcast file not found: $broadcast_file" >&2
        echo "Please provide a valid broadcast file path." >&2
        return 1
    fi
    
    # Determine network name for display
    local network
    case "$chain_id" in
        30) network="mainnet" ;;
        31) network="testnet/alphanet" ;;
        33) network="regtest" ;;
        31337) network="local" ;;
        *) network="chain-$chain_id" ;;
    esac
    
    # Print header
    echo "=========================================="
    echo "$title"
    echo "=========================================="
    echo "Network: $network"
    echo "Chain ID: $chain_id"
    echo "API: $api_url"
    echo "Broadcast file: $broadcast_file"
    echo "Compiler: $COMPILER_VERSION"
    echo "Optimizer: $OPTIMIZER_ENABLED (runs: $OPTIMIZER_RUNS)"
    echo "EVM: $EVM_VERSION"
    echo ""
    
    # Build implementation address -> contract name map
    local impl_map
    impl_map=$(build_impl_map "$broadcast_file")
    
    # Verify all implementation contracts
    verify_all_implementations "$broadcast_file" "$chain_id" "$verifier" "$api_url"
    
    # Verify all proxy contracts
    verify_all_proxies "$broadcast_file" "$impl_map" "$chain_id" "$verifier" "$api_url"
    
    # Print footer
    echo "=========================================="
    echo "Verification Complete!"
    echo "=========================================="
    echo ""
    echo "All contracts have been submitted for verification."
    echo "Check the explorer to confirm verification status:"
    echo "  $explorer_url"
    echo ""
}
