#!/bin/bash
# Common functions for ownership scripts

validate_network_argument() {
    local network="${1}"

    if [[ -z "$network" ]]; then
        echo "Error: Network must be provided" >&2
        echo "Valid networks: testnet, mainnet, alphanet, local, regtest" >&2
        return 1
    fi

    return 0
}

setup_network() {
    local network="${1}"

    # Validate network argument
    if ! validate_network_argument "$network"; then
        return 1
    fi

    # Set network-specific variables
    case "$network" in
        testnet)
            export NETWORK=testnet
            export RPC=$RSK_TESTNET_RPC
            export CHAIN_ID=31
            ;;
        mainnet)
            export NETWORK=mainnet
            export RPC=$RSK_MAINNET_RPC
            export CHAIN_ID=30
            ;;
        alphanet)
            export NETWORK=alphanet
            export RPC=$RSK_ALPHANET_RPC
            export CHAIN_ID=31
            ;;
        local)
            export NETWORK=local
            export RPC=$LOCAL_RPC
            export CHAIN_ID=31337
            ;;
        regtest)
            export NETWORK=regtest
            export RPC=$RSK_REGTEST_RPC
            export CHAIN_ID=33
            ;;
        *)
            echo "Error: Invalid network '$network'" >&2
            echo "Valid networks: testnet, mainnet, alphanet, local, regtest" >&2
            return 1
            ;;
    esac

    # Validate RPC is set
    if [[ -z "$RPC" ]]; then
        echo "Error: RPC URL not set for network '$NETWORK'" >&2
        return 1
    fi

    return 0
}
