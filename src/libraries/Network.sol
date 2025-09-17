// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

/// @notice Represents different Bitcoin networks
/// @dev Used to distinguish between mainnet, testnet, and regtest environments
enum BtcNetwork {
    /// @notice Bitcoin mainnet - the production network
    MAINNET,
    /// @notice Bitcoin testnet - the public test network
    TESTNET,
    /// @notice Bitcoin regtest - local development network
    REGTEST,
    /// @notice This must always be the last element since it represents the total count of enum elements
    /// @dev Used for validation and iteration over the enum values
    LENGTH
}

/// @title ChainIds
/// @notice Library containing chain ID constants for different RSK networks
/// @dev Provides standardized chain IDs for RSK mainnet, testnet and local networks
library ChainIds {
    /// @notice RSK mainnet - the production network
    uint256 constant RSK_MAINNET = 30;

    /// @notice RSK testnet - the public test network
    uint256 constant RSK_TESTNET = 31;

    /// @notice Local development network (Hardhat/Foundry default)
    /// @dev Used for local testing and development environments
    uint256 constant LOCAL = 31337;
}
