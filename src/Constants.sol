// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

/// @title Constants
abstract contract Constants {
    // Constants
    uint32 constant SEQUENCE = 0xFFFFFFFD;
    uint32 constant LOCKTIME = 0;
    uint32 constant BTC_TX_VERSION = 2;
    uint64 constant VOUT_INDEX_TAPTREE = 0;
    uint64 constant VOUT_INDEX_SPEED_UP = 1;
    uint8 constant SIGNATURE_NONCE_LENGTH = 66;
}
