// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

/// @title Constants
/// @notice Library containing all constants used throughout the union bridge contracts
/// @dev This library defines Bitcoin transaction parameters, fee structures, and system configuration values
/// @dev All constants are carefully chosen to ensure compatibility with Bitcoin and RSK networks
library Constants {
    // Bitcoin Transaction Constants
    /// @dev Sequence number for replace-by-fee Bitcoin transactions (0xFFFFFFFD)
    /// @dev This enables replace-by-fee functionality for Bitcoin transactions
    uint32 constant SEQUENCE = 0xFFFFFFFD;

    /// @dev Locktime value for Bitcoin transactions (0 = no locktime)
    /// @dev Used to specify when a transaction can be included in a block
    uint32 constant LOCKTIME = 0;

    /// @dev Bitcoin transaction version (2 = supports SegWit and Taproot)
    /// @dev Version 2 enables modern Bitcoin features like Taproot
    uint32 constant BTC_TX_VERSION = 2;

    /// @dev Output index for Taproot output in peg-in Bitcoin transactions
    /// @dev First output (index 0) contains the main Taproot payment
    uint32 constant VOUT_INDEX_TAPTREE = 0;

    /// @dev Output index for speed-up output in peg-in Bitcoin transactions
    /// @dev Second output (index 1) contains the speed-up payment for CPFP
    uint32 constant VOUT_INDEX_SPEED_UP = 1;

    /// @dev Signature hash type for Bitcoin transactions (SIGHASH_ALL = 0x01)
    /// @dev Indicates that all inputs and outputs are signed
    uint8 constant SIGHASH_ALL = 0x01;

    // Fee and Amount Constants
    /// @dev Fee for P2TR Bitcoin transactions in satoshis
    /// @dev TODO: Check if this is correct for current network conditions
    uint64 constant P2TR_FEE = 335;

    /// @dev Speed-up amount in satoshis for CPFP Bitcoin transactions
    /// @dev Amount sent to speed-up output to accelerate parent transaction
    uint64 constant SPEED_UP_AMOUNT = 300;

    /// @dev Dust threshold in satoshis for Bitcoin transactions
    /// @dev Minimum amount required for a Bitcoin output to be considered valid
    uint64 constant DUST_THRESHOLD = 300;

    /// @dev Timelock blocks for Bitcoin transactions
    /// @dev TODO: this should be a parameter not a constant
    uint8 constant TIMELOCK_BLOCKS = 1;

    /// @dev Length of signature nonce in bytes
    /// @dev Used for multi-signature operations in committee transactions
    uint8 constant SIGNATURE_NONCE_LENGTH = 66;

    // Stream and Packet Constants
    /// @dev Number of slots per packet in the stream
    /// @dev NOTE: SLOTS_PER_PACKET should be smaller than 2^16 to avoid overflow of Stream.pegoutSlotPointer
    uint8 constant SLOTS_PER_PACKET = 100;

    /// @dev Threshold for slot usage that triggers new committee creation
    /// @dev When 80% of slots are filled, a new committee is created
    uint8 constant SLOT_USAGE_THRESHOLD = 80;

    /// @dev Maximum number of stream denominations supported by the bridge
    /// @dev Limits the number of different Bitcoin amounts that can be processed
    uint64 constant MAX_DENOMINATIONS_SIZE = 10;

    /// @dev Maximum number of candidates to a committee for a particular role and stream denominations
    uint256 constant MAX_CANDIDATES_SIZE_PER_ROLE = 100;
}
