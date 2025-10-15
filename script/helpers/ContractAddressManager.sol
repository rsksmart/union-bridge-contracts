// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ChainIds} from "src/libraries/Network.sol";

/// @title ContractAddressManager
/// @notice Helper library to get contract addresses based on the current network
/// @dev Uses environment variables to determine which network's addresses to use
abstract contract ContractAddressManager is Script {
    /// @notice Get the PegManager contract address for the current network
    /// @return The PegManager address
    function getPegManager() internal view returns (address) {
        if (block.chainid == ChainIds.LOCAL) {
            return vm.envAddress("LOCAL_PEG_MANAGER");
        } else if (block.chainid == ChainIds.RSK_MAINNET) {
            return vm.envAddress("MAINNET_PEG_MANAGER");
        }

        // For testnet/alphanet (both chain ID 31), check NETWORK env var
        string memory network = vm.envString("NETWORK");
        if (keccak256(bytes(network)) == keccak256(bytes("alphanet"))) {
            return vm.envAddress("ALPHANET_PEG_MANAGER");
        } else if (keccak256(bytes(network)) == keccak256(bytes("testnet"))) {
            return vm.envAddress("TESTNET_PEG_MANAGER");
        }

        revert("Unsupported network");
    }

    /// @notice Get the StreamManager contract address for the current network
    /// @return The StreamManager address
    function getStreamManager() internal view returns (address) {
        if (block.chainid == ChainIds.LOCAL) {
            return vm.envAddress("LOCAL_STREAM_MANAGER");
        } else if (block.chainid == ChainIds.RSK_MAINNET) {
            return vm.envAddress("MAINNET_STREAM_MANAGER");
        }

        // For testnet/alphanet (both chain ID 31), check NETWORK env var
        string memory network = vm.envString("NETWORK");
        if (keccak256(bytes(network)) == keccak256(bytes("alphanet"))) {
            return vm.envAddress("ALPHANET_STREAM_MANAGER");
        } else if (keccak256(bytes(network)) == keccak256(bytes("testnet"))) {
            return vm.envAddress("TESTNET_STREAM_MANAGER");
        }

        revert("Unsupported network");
    }

    /// @notice Get the CommitteeRegistry contract address for the current network
    /// @return The CommitteeRegistry address
    function getCommitteeRegistry() internal view returns (address) {
        if (block.chainid == ChainIds.LOCAL) {
            return vm.envAddress("LOCAL_COMMITTEE_REGISTRY");
        } else if (block.chainid == ChainIds.RSK_MAINNET) {
            return vm.envAddress("MAINNET_COMMITTEE_REGISTRY");
        }

        // For testnet/alphanet (both chain ID 31), check NETWORK env var
        string memory network = vm.envString("NETWORK");
        if (keccak256(bytes(network)) == keccak256(bytes("alphanet"))) {
            return vm.envAddress("ALPHANET_COMMITTEE_REGISTRY");
        } else if (keccak256(bytes(network)) == keccak256(bytes("testnet"))) {
            return vm.envAddress("TESTNET_COMMITTEE_REGISTRY");
        }

        revert("Unsupported network");
    }

    /// @notice Get the Bridge contract address for the current network
    /// @return The Bridge address (mock for local only, real bridge for alphanet/testnet/mainnet)
    function getBridge() internal view returns (address payable) {
        if (block.chainid == ChainIds.LOCAL) {
            return payable(vm.envAddress("LOCAL_BRIDGE_MOCK"));
        }

        // For all other networks (alphanet, testnet, mainnet), use real RSK Bridge
        return payable(0x0000000000000000000000000000000001000006);
    }
}
