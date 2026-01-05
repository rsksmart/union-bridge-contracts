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

    // Request Peg-in Transaction Output Indices
    /// @dev Output index for Taproot output in request peg-in Bitcoin transactions
    /// @dev First output (index 0) contains the main Taproot payment
    uint32 constant REQUEST_PEGIN_VOUT_TAPTREE = 0;

    /// @dev Output index for OP_RETURN output in request peg-in Bitcoin transactions
    /// @dev Second output (index 1) contains metadata: packet number, RSK address, BTC reimbursement key
    uint32 constant REQUEST_PEGIN_VOUT_OP_RETURN = 1;

    /// @dev Output index for enabler output in request peg-in Bitcoin transactions
    /// @dev Third output (index 2) contains the enabler output with dispute keys
    uint32 constant REQUEST_PEGIN_VOUT_ENABLER = 2;

    // Accept Peg-in Transaction Input Indices
    /// @dev Input index for consuming the request peg-in taptree output in accept peg-in Bitcoin transactions
    /// @dev First input (index 0) spends the request peg-in taptree UTXO
    uint32 constant ACCEPT_PEGIN_VIN_TAPTREE = 0;

    /// @dev Input index for consuming the request peg-in enabler output in accept peg-in Bitcoin transactions
    /// @dev Second input (index 1) spends the request peg-in enabler UTXO
    uint32 constant ACCEPT_PEGIN_VIN_ENABLER = 1;

    // Accept Peg-in Transaction Output Indices
    /// @dev Output index for Taproot output in accept peg-in Bitcoin transactions
    /// @dev First output (index 0) contains the P2TR payment to the committee
    uint32 constant ACCEPT_PEGIN_VOUT_TAPTREE = 0;

    /// @dev Output index for enabler output in accept peg-in Bitcoin transactions
    /// @dev Second output (index 1) contains the enabler output with operator dispute keys only
    uint32 constant ACCEPT_PEGIN_VOUT_ENABLER = 1;

    /// @dev Output index for speed-up output in accept peg-in Bitcoin transactions
    /// @dev Third output (index 2) contains the speed-up payment for CPFP
    uint32 constant ACCEPT_PEGIN_VOUT_SPEED_UP = 2;

    /// @dev Output index for user output in advance funds Bitcoin transactions
    /// @dev First output (index 0) contains the payment to the user
    uint32 constant ADVANCE_FUNDS_VOUT_USER = 0;

    /// @dev Output index for OP_RETURN output in advance funds Bitcoin transactions
    /// @dev Second output (index 1) contains metadata for tracking
    uint32 constant ADVANCE_FUNDS_VOUT_OP_RETURN = 1;

    /// @dev Input index for user input in operator take Bitcoin transactions
    /// @dev First input (index 0) spends the accept peg-in output UTXO
    uint32 constant OPERATOR_TAKE_VIN_ACCEPT_PEGIN = 0;

    /// @dev Input index for reimbursement kickoff input in operator take Bitcoin transactions
    /// @dev Second input (index 1) spends the reimbursement kickoff UTXO
    uint32 constant OPERATOR_TAKE_VIN_REIMBURSEMENT_KICKOFF = 1;

    /// @dev Output index for user in operator take Bitcoin transactions
    /// @dev First output (index 0) contains the payment to the user
    uint32 constant OPERATOR_TAKE_VOUT_USER = 0;

    // Pegout Transaction Input Indices
    /// @dev Input index for consuming the accept peg-in taptree output in pegout Bitcoin transactions
    /// @dev First input (index 0) spends the accept peg-in taptree UTXO
    uint32 constant PEGOUT_VIN_TAPTREE = 0;

    /// @dev Input index for consuming the accept peg-in enabler output in pegout Bitcoin transactions
    /// @dev Second input (index 1) spends the accept peg-in enabler UTXO
    uint32 constant PEGOUT_VIN_ENABLER = 1;

    // Pegout Transaction Output Indices
    /// @dev Output index for user payment output in pegout Bitcoin transactions
    /// @dev First output (index 0) contains the payment to the user
    uint32 constant PEGOUT_VOUT_USER = 0;

    /// @dev Output index for speed-up output in pegout Bitcoin transactions
    /// @dev Second output (index 1) contains the speed-up payment for CPFP
    uint32 constant PEGOUT_VOUT_SPEED_UP = 1;

    // Transaction Input/Output Counts
    /// @dev Number of outputs in a request peg-in transaction
    /// @dev Includes: taptree output, OP_RETURN metadata, and enabler output
    uint32 constant REQUEST_PEGIN_OUTPUT_COUNT = 3;

    /// @dev Number of inputs in an accept peg-in transaction
    /// @dev Includes: request pegin taptree input and request pegin enabler input
    uint32 constant ACCEPT_PEGIN_INPUT_COUNT = 2;

    /// @dev Number of outputs in an accept peg-in transaction
    /// @dev Includes: taptree output, enabler output, and speed-up output
    uint32 constant ACCEPT_PEGIN_OUTPUT_COUNT = 3;

    /// @dev Number of inputs in a pegout transaction
    /// @dev Includes: accept pegin taptree input and accept pegin enabler input
    uint32 constant PEGOUT_INPUT_COUNT = 2;

    /// @dev Number of outputs in a pegout transaction
    /// @dev Includes: user payment output and speed-up output
    uint32 constant PEGOUT_OUTPUT_COUNT = 2;

    /// @dev Signature hash type for Bitcoin transactions (SIGHASH_ALL = 0x01)
    /// @dev Indicates that all inputs and outputs are signed
    uint8 constant SIGHASH_ALL = 0x01;

    // Fee and Amount Constants
    /// @dev Fee for P2TR Bitcoin transactions in satoshis
    /// @dev TODO: Check if this is correct for current network conditions
    uint64 constant P2TR_FEE = 335;

    /// @dev Speed-up amount in satoshis for CPFP Bitcoin transactions
    /// @dev Amount sent to speed-up output to accelerate parent transaction
    uint64 constant SPEED_UP_AMOUNT = 540;

    /// @dev Enabler output amount in satoshis for dispute resolution
    /// @dev Amount sent to enabler output for operator dispute mechanism
    uint64 constant ENABLER_AMOUNT = 540;

    /// @dev Reimbursement kickoff amount in satoshis for Bitcoin transactions
    uint64 constant REIMBURSEMENT_KICKOFF_AMOUNT = 5137;

    /// @dev Dust threshold in satoshis for Bitcoin transactions
    /// @dev Minimum amount required for a Bitcoin output to be considered valid
    uint64 constant DUST_THRESHOLD = 300;

    /// @dev Timelock blocks for Bitcoin transactions
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
