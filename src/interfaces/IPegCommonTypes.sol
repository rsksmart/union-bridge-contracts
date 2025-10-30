// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

import {BtcTransaction} from "./IBitcoinManager.sol";

/// @notice Represents a Bitcoin transaction with SPV proof for bridge validation
/// @dev Contains the transaction data along with merkle proof for block inclusion verification
/// @dev Used to prove that a Bitcoin transaction is included in a specific block without full node verification
struct BtcTxSPVProof {
    /// @notice The Bitcoin block hash where the transaction was included
    /// @dev Used to verify the block exists and has sufficient confirmations
    bytes32 blockHash;
    /// @notice The Bitcoin transaction data
    /// @dev Contains all transaction details needed for transaction id calculation
    BtcTransaction btcTx;
    /// @notice Merkle path indicating left/right traversal in the merkle tree
    /// @dev Each bit represents whether to go left (0) or right (1) in the merkle tree
    /// @dev This is an optimization to avoid sending the complete merkle tree
    uint256 merkleBranchPath;
    /// @notice Array of merkle branch hashes for proof verification
    /// @dev These hashes are used together with the merkleBranchPath to reconstruct the merkle root
    /// @dev Allows verification of transaction inclusion without full merkle tree
    bytes32[] merkleBranchHashes;
}

/// @notice Represents the current status of a peg-in or peg-out operation
/// @dev Tracks the progression of funds through the bridge system
enum PegStatus {
    /// @notice Operation has not been registered yet
    NOT_REGISTERED,
    /// @notice Operation has been registered and is awaiting committee acceptance
    REGISTERED,
    /// @notice Operation has been accepted by the committee and funds are in the committee account
    ACCEPTED,
    /// @notice Operation has been taken by the user and is awaiting committee acceptance
    USER_TAKE,
    /// @notice Operation has been taken by the operator and is awaiting committee acceptance
    OPERATOR_TAKE,
    /// @notice Operation has been won by the operator and is awaiting committee acceptance
    OPERATOR_WON,
    /// @notice Operation has been completed and funds have been paid out
    COMPLETED,
    /// @notice This must always be the last element since it represents the total count of enum elements
    /// @dev Used for validation and iteration over the enum values
    LENGTH
}

/// @notice Represents the position of funds within the stream and packet system
/// @dev Tracks where funds are located in the hierarchical stream/packet/slot structure
struct StreamPosition {
    /// @notice The stream ID where the funds are located
    uint64 streamId;
    /// @notice The packet number within the stream
    uint64 packetNumber;
    /// @notice The slot ID within the packet
    uint64 slotId;
    /// @notice The current status of the peg operation
    PegStatus pegStatus;
}

/// @notice Temporary information stored during peg-in request processing
/// @dev Contains data needed for the accept peg-in phase
struct RequestPeginTempInfo {
    /// @notice The RSK address that will receive the RBTC
    address rskDestinationAddress;
    /// @notice The user's Bitcoin public key for reimbursement (x-coordinate only)
    bytes32 btcReimbursementPubKey;
    /// @notice The signature hash that committee members need to sign
    bytes32 acceptPeginSignatureHash;
}

/// @notice Temporary information stored during peg-out processing
/// @dev Contains data needed for peg-out transaction validation
struct PegoutTempInfo {
    /// @notice The user's public key that will receive the Bitcoin funds
    bytes userPubKey;
    /// @notice Timestamp when the peg-out was initially created
    uint256 createdAt;
    /// @notice Timestamp when the operator take was last updated/triggered
    uint256 operatorTakeUpdatedAt;
    /// @notice The committee ID responsible for signing this peg-out
    uint128 committeeId;
    /// @notice The operator address that will advance the funds to the user
    address takeOperatorAddress;
    /// @notice The public key of the selected operator for Bitcoin transactions (x-coordinate only)
    bytes32 takeOperatorPubKey;
}

struct PegManagerSettings {
    /// @notice Timeout for the user to take the pegout
    /// @dev This is the time the members has to sign the pegout transaction
    uint256 userTakeTimeout; // Timeout for the user to take the pegout
    /// @notice Timeout for the operator to take the pegout
    /// @dev This is the time the operator has to advance the funds to the user and present the proof
    uint256 operatorTakeTimeout; // Timeout for the operator to take the pegout
}
