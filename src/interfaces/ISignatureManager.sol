// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

import {IAccessControl} from "./IAccessControl.sol";

/// @notice Represents signature data for a committee member
/// @dev Contains the member's public key, signature, and nonce for multi-signature operations
struct SignatureData {
    /// @notice The signature provided by the member
    bytes32 signature;
    /// @notice The nonce used for signature generation (should be 66 bytes)
    bytes nonce;
}

/// @notice Represents the state of signatures for a specific hash
/// @dev Tracks partial signatures, missing signatures, and committee information
struct Signatures {
    /// @notice Mapping of member addresses to their signature data
    mapping(address memberAddress => SignatureData) partialSignaturesData;
    /// @notice Number of missing signatures
    uint8 missingSignatures;
    /// @notice Number of missing nonces
    uint8 missingNonces;
    /// @notice ID of the committee responsible for these signatures
    uint128 committeeId;
}

/// @notice Represents OperatorTake transaction data for a committee member
/// @dev Used for OperatorTake operations (advance funds to the user)
struct OperatorTakeData {
    /// @notice The transaction hash provided by the member
    bytes32 txHash;
    /// @notice The member's address
    address memberAddress;
}

/// @notice Represents the state of OperatorTake transaction hashes for a specific accept peg-in
/// @dev Tracks OperatorTake transaction hashes provided by committee members
struct OperatorTakeTxHashes {
    /// @notice Mapping of member addresses to their OperatorTake transaction hashes
    mapping(address memberAddress => bytes32 operatorTakeTxHash) txHashes;
    /// @notice Number of missing OperatorTake transaction hashes
    uint8 missingHashes;
    /// @notice ID of the committee responsible for these hashes
    uint128 committeeId;
}

/// @notice Interface for managing multi-signature operations in the union bridge
/// @dev This interface provides functions for collecting and validating committee signatures
/// @dev Handles member signatures for both pegin and pegout transactions
interface ISignatureManager is IAccessControl {
    /// @notice Initializes signature collection for a specific hash
    /// @dev Sets up the signature tracking structure for committee members
    /// @param _hashToSign The hash that committee members need to sign
    /// @param _committeeId The ID of the committee responsible for signing
    function initSignatures(bytes32 _hashToSign, uint128 _committeeId) external;

    /// @notice Adds a nonce for a committee member
    /// @dev Called by committee members to provide their nonce for signature generation
    /// @param _hashToSign The hash being signed
    /// @param _nonce The nonce provided by the member (should be 66 bytes)
    /// @return True if the nonce was successfully added
    function addMemberNonce(bytes32 _hashToSign, bytes memory _nonce) external returns (bool);

    /// @notice Adds a signature for a committee member
    /// @dev Called by committee members to provide their signature
    /// @param _hashToSign The hash being signed
    /// @param _signature The signature provided by the member
    /// @return True if the signature was successfully added
    function addMemberSignature(bytes32 _hashToSign, bytes32 _signature) external returns (bool);

    /// @notice Checks if all signatures are ready for a specific hash
    /// @param _hashToSign The hash to check signatures for
    /// @return True if all required signatures have been collected
    function checkAllSignaturesReady(bytes32 _hashToSign) external view returns (bool);

    /// @notice Retrieves all partial signatures for a specific hash
    /// @param _hashToSign The hash to get signatures for
    /// @return Array of signature data from all committee members
    function getPartialSignatures(bytes32 _hashToSign) external view returns (SignatureData[] memory);

    /// @notice Gets the status of signatures for a specific hash
    /// @param _hashToSign The hash to check status for
    /// @return missingSignatures Number of missing signatures
    /// @return missingNonces Number of missing nonces
    /// @return committeeId The committee ID responsible for these signatures
    function getSignaturesStatus(bytes32 _hashToSign)
        external
        view
        returns (uint8 missingSignatures, uint8 missingNonces, uint128 committeeId);

    /// @notice Initializes OperatorTake transaction hash collection for a specific accept peg-in
    /// @dev Sets up the OperatorTake hash tracking structure for committee members
    /// @param _acceptPeginTxHash The accept peg-in transaction hash
    /// @param _committeeId The ID of the committee responsible for OperatorTake operations
    function initOperatorTakeTxHashes(bytes32 _acceptPeginTxHash, uint128 _committeeId) external;

    /// @notice Adds a OperatorTake transaction hash for a committee member
    /// @dev Called by committee operators to provide their OperatorTake transaction hash
    /// @param _acceptPeginTxHash The accept peg-in transaction hash
    /// @param _takeTxhash The OperatorTake transaction hash provided by the member
    function addOperatorTakeTxHash(bytes32 _acceptPeginTxHash, bytes32 _takeTxhash) external;

    /// @notice Checks if all OperatorTake transaction hashes are ready
    /// @param _acceptPeginTxHash The accept peg-in transaction hash
    /// @return True if all required OperatorTake hashes have been collected
    function checkAllOperatorTakesHashesReady(bytes32 _acceptPeginTxHash) external view returns (bool);

    /// @notice Retrieves all OperatorTake data for a specific accept peg-in
    /// @param _acceptPeginTxHash The accept peg-in transaction hash
    /// @return Array of OperatorTake data from all committee members
    function getOperatorTakeData(bytes32 _acceptPeginTxHash) external view returns (OperatorTakeData[] memory);

    /// @notice Gets the committee ID for a specific accept peg-in transaction hash
    /// @param _acceptPeginTxHash The accept peg-in transaction hash
    /// @return The committee ID responsible for this accept peg-in
    function getCommitteeIdByAcceptPeginTxHash(bytes32 _acceptPeginTxHash) external view returns (uint128);

    // Events
    /// @notice Event emitted when a nonce is added by a committee member
    /// @param hashToSign The hash being signed
    /// @param memberAddress The member's RSK address
    /// @param nonce The nonce provided by the member
    event NonceAdded(bytes32 indexed hashToSign, address indexed memberAddress, bytes nonce);

    /// @notice Event emitted when all nonces are ready for a hash
    /// @param hashToSign The hash for which all nonces are ready
    event AllNoncesReady(bytes32 indexed hashToSign);

    /// @notice Event emitted when a signature is added by a committee member
    /// @param hashToSign The hash being signed
    /// @param memberAddress The member's RSK address
    /// @param signature The signature provided by the member
    event SignatureAdded(bytes32 indexed hashToSign, address indexed memberAddress, bytes32 signature);

    /// @notice Event emitted when all signatures are ready for a hash
    /// @param hashToSign The hash for which all signatures are ready
    event AllSignaturesReady(bytes32 indexed hashToSign);

    /// @notice Event emitted when a OperatorTake transaction hash is added
    /// @param acceptPeginTxHash The accept peg-in transaction hash
    /// @param memberAddress The member's address
    /// @param hash The OperatorTake transaction hash provided by the member
    event OperatorTakeTxHashAdded(bytes32 acceptPeginTxHash, address memberAddress, bytes32 hash);

    /// @notice Event emitted when all OperatorTake transaction hashes are added
    /// @param acceptPeginTxHash The accept peg-in transaction hash
    event AllOperatorTakeTxHashesAdded(bytes32 acceptPeginTxHash);

    // Errors
    /// @notice Thrown when the committee registry address is set to zero
    error CommitteeRegistryAddressZero();

    /// @notice Thrown when a hash to sign is not found
    /// @param hashToSign The hash that was not found
    error HashToSignNotFound(bytes32 hashToSign);

    /// @notice Thrown when the nonce length is invalid
    /// @param actual The actual nonce length
    /// @param expected The expected nonce length (66 bytes)
    error InvalidNonceLength(uint256 actual, uint8 expected);

    /// @notice Thrown when a member has already added a nonce
    /// @param memberAddress The member's address
    /// @param nonce The nonce that was already added
    error MemberAlreadyAddedNonce(address memberAddress, bytes nonce);

    /// @notice Thrown when all nonces are not present
    /// @param hashToSign The hash for which nonces are missing
    error AllNoncesAreNotPresent(bytes32 hashToSign);

    /// @notice Thrown when a signature is invalid
    error InvalidSignature();

    /// @notice Thrown when a member has already signed
    /// @param memberAddress The member's address
    /// @param pegoutTxHash The peg-out transaction hash
    error MemberHasAlreadySigned(address memberAddress, bytes32 pegoutTxHash);

    /// @notice Thrown when a member is not found
    /// @param memberAddress The member's address
    error MemberNotFound(address memberAddress);

    /// @notice Thrown when a member is not found in a committee
    /// @param committeeId The committee ID
    /// @param memberAddress The member's address
    error MemberNotFoundInCommittee(uint128 committeeId, address memberAddress);

    /// @notice Thrown when the hash to sign is invalid
    /// @param hashToSign The invalid hash
    error InvalidHashToSign(bytes32 hashToSign);

    /// @notice Thrown when signatures are already initialized
    /// @param hashToSign The hash for which signatures are already initialized
    error SignaturesAlreadyInitialized(bytes32 hashToSign);

    /// @notice Thrown when the accept peg-in transaction hash is invalid
    /// @param acceptPeginTxHash The invalid accept peg-in transaction hash
    error InvalidAcceptPeginTxHash(bytes32 acceptPeginTxHash);

    /// @notice Thrown when OperatorTake transaction hashes are already initialized
    /// @param acceptPeginTxHash The accept peg-in transaction hash
    error OperatorTakeTxHashesAlreadyInitialized(bytes32 acceptPeginTxHash);

    /// @notice Thrown when an accept peg-in transaction hash is not found
    /// @param acceptPeginTxHash The accept peg-in transaction hash that was not found
    error AcceptPeginTxHashNotFound(bytes32 acceptPeginTxHash);

    /// @notice Thrown when all OperatorTake transaction hashes are already present
    /// @param acceptPeginTxHash The accept peg-in transaction hash
    error AllOperatorTakeTxHashesAlreadyPresent(bytes32 acceptPeginTxHash);

    /// @notice Thrown when a hash is invalid
    /// @param hash The invalid hash
    error InvalidHash(bytes32 hash);

    /// @notice Thrown when a member is not an operator
    /// @param committeeId The committee ID
    /// @param memberAddress The member's address
    error MemberIsNotOperator(uint128 committeeId, address memberAddress);

    /// @notice Thrown when a member has already added a OperatorTake transaction hash
    /// @param acceptPeginTxHash The accept peg-in transaction hash
    /// @param memberAddress The member's address
    /// @param hash The OperatorTake transaction hash that was already added
    error MemberAlreadyAddedOperatorTakeTxHash(bytes32 acceptPeginTxHash, address memberAddress, bytes32 hash);
}
