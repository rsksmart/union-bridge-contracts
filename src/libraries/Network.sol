// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

enum BtcNetwork {
    MAINNET,
    TESTNET,
    REGTEST
}

library ChainIds {
    uint256 constant RSK_MAINNET = 30;
    uint256 constant RSK_TESTNET = 31;
    uint256 constant LOCAL = 31337;
}
