#!/bin/bash
# Individual contract verification functions
# These functions verify a single implementation or proxy contract

# Source configuration
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$CURRENT_PATH/verify-config.sh"

# Extract initialize() call data from init_data
# The init_data structure: first 32 bytes (64 hex chars) = selector + padding, rest = actual data
extract_init_data() {
    local init_data="$1"
    local data="${init_data#0x}"  # Remove 0x prefix if present
    echo "0x${data:64}"  # Skip first 32 bytes (64 hex chars of the selector right-padded with 0s) and return the rest
}

# Verify an implementation contract
verify_implementation() {
    local contract_name="$1"
    local contract_addr="$2"
    local chain_id="$3"
    local verifier="$4"
    local verifier_url="$5"
    
    echo "Verifying $contract_name ($contract_addr)..."
    
    forge verify-contract \
        --chain-id "$chain_id" \
        --watch \
        --compiler-version "$COMPILER_VERSION" \
        --optimizer-runs "$OPTIMIZER_RUNS" \
        --verifier "$verifier" \
        --verifier-url "$verifier_url" \
        "$contract_addr" \
        "src/${contract_name}.sol:${contract_name}" || {
        echo "  ⚠️  Warning: Verification failed for $contract_name"
        return 1
    }
    
    echo "  ✅ Successfully verified $contract_name"
    echo ""
}

# Verify a proxy contract
verify_proxy() {
    local contract_name="$1"
    local proxy_addr="$2"
    local chain_id="$3"
    local verifier="$4"
    local verifier_url="$5"
    local broadcast_file="${6:-$PROJECT_ROOT/broadcast/DeployScript.s.sol/$chain_id/run-latest.json}"
    echo "Using broadcast file: $broadcast_file"
    echo "Verifying ${contract_name} Proxy ($proxy_addr)..."
    
    # Extract impl_addr and init_data from broadcast file
    # Match by contractName, transactionType (CREATE), and contractAddress (case-insensitive)
    local impl_addr init_data
    impl_addr=$(jq -r --arg addr "$proxy_addr" '.transactions[] | select(.contractName == "ERC1967Proxy" and .transactionType == "CREATE" and (.contractAddress | ascii_downcase) == ($addr | ascii_downcase)) | .arguments[0]' "$broadcast_file" | head -1)
    init_data=$(jq -r --arg addr "$proxy_addr" '.transactions[] | select(.contractName == "ERC1967Proxy" and .transactionType == "CREATE" and (.contractAddress | ascii_downcase) == ($addr | ascii_downcase)) | .arguments[1]' "$broadcast_file" | head -1)
    
    if [ -z "$impl_addr" ] || [ "$impl_addr" = "null" ]; then
        echo "  ⚠️  Error: Could not find proxy $proxy_addr in broadcast file"
        return 1
    fi
    
    if [ -z "$init_data" ] || [ "$init_data" = "null" ]; then
        echo "  ⚠️  Error: Could not find init_data for proxy $proxy_addr in broadcast file"
        return 1
    fi
    
    # Extract the actual initialize() call data
    local actual_init_data=$(extract_init_data "$init_data")
    
    if [ -z "$actual_init_data" ] || [ "$actual_init_data" = "0x" ]; then
        echo "  ⚠️  Error: Could not extract initialize() call data from init_data"
        echo "  Original init_data length: ${#init_data} characters"
        return 1
    fi
    
    echo "  Extracted init data: $actual_init_data (length: $((${#actual_init_data} - 2)) hex chars)"
    
    # Encode constructor arguments
    local constructor_args=$(cast abi-encode "constructor(address,bytes)" "$impl_addr" "$actual_init_data")
    
    forge verify-contract \
        --chain-id "$chain_id" \
        --watch \
        --compiler-version "$COMPILER_VERSION" \
        --optimizer-runs "$OPTIMIZER_RUNS" \
        --constructor-args "$constructor_args" \
        --verifier "$verifier" \
        --verifier-url "$verifier_url" \
        "$proxy_addr" \
        "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy" || {
        echo "  ⚠️  Warning: Verification failed for ${contract_name} Proxy"
        return 1
    }
    
    echo "  ✅ Successfully verified ${contract_name} Proxy"
    echo ""
}
