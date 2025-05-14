// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

/// @title Constants
library Constants {
    // Constants
    uint32 constant SEQUENCE = 0xFFFFFFFD;
    uint32 constant LOCKTIME = 0;
    uint32 constant BTC_TX_VERSION = 2;
    uint32 constant VOUT_INDEX_TAPTREE = 0;
    uint32 constant VOUT_INDEX_SPEED_UP = 1;
    uint8 constant SIGHASH_ALL = 0x01;
    // Btc P2TR Fees in satoshis
    // TODO: Check if this is correct
    uint64 constant P2TR_FEE = 335;
    // Speed up amount in satoshis
    uint64 constant SPEED_UP_AMOUNT = 300;
    // Dust threshold in satoshis
    uint64 constant DUST_THRESHOLD = 300;
    // TODO: this should be a parameter not a constant
    uint8 constant TIMELOCK_BLOCKS = 1;
    uint8 constant SIGNATURE_NONCE_LENGTH = 66;
    uint8 constant SLOTS_PER_PACKET = 100;
    uint8 constant SLOT_USAGE_THRESHOLD = 80;
}
