// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

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
    /// @notice The Operator Take Txid provided by the member
    bytes32 takeTxid;
    /// @notice The Operator Won Txid provided by the member
    bytes32 wonTxid;
    /// @notice The member's address
    address memberAddress;
}

/// @notice Represents the state of OperatorTake transaction id's for a specific accept peg-in
/// @dev Tracks OperatorTake and OperatorWon transaction id's provided by committee members
struct OperatorTakeTxids {
    /// @notice Mapping of member addresses to their OperatorTake transaction id's
    mapping(address memberAddress => bytes32 operatorTakeTxid) takeTxids;
    /// @notice Mapping of member addresses to their OperatorWon transaction id's
    mapping(address memberAddress => bytes32 operatorWonTxid) wonTxids;
    /// @notice Number of missing OperatorTake transaction id's
    uint8 missingHashes;
    /// @notice ID of the committee responsible for these hashes
    uint128 committeeId;
}

/// @notice Interface for managing multi-signature operations in the union bridge
/// @dev This interface provides functions for collecting and validating committee signatures
/// @dev Handles member signatures for both pegin and pegout transactions
interface ISignatureManager {
    /// @notice Initializes signature collection for a specific txid
    /// @dev Sets up the signature tracking structure for committee members
    /// @param _txid The txid that committee members need to sign
    /// @param _committeeId The ID of the committee responsible for signing
    function initSignatures(bytes32 _txid, uint128 _committeeId) external;

    /// @notice Adds a nonce for a committee member to the signature collection
    /// @dev Nonces are required for Musig2 signature aggregation
    /// @param _txid The txid that needs to be signed by the committee
    /// @param _nonce The 66-byte nonce for the Musig2 protocol
    /// @return true if all nonces are now present, false otherwise
    function addMemberNonce(bytes32 _txid, bytes memory _nonce) external returns (bool);

    /// @notice Adds a signature for a committee member to the signature collection
    /// @dev Signatures can only be added after all nonces are present
    /// @param _txid The hash that needs to be signed by the committee
    /// @param _signature The signature for the hash
    /// @return true if all signatures are now present, false otherwise
    function addMemberSignature(bytes32 _txid, bytes32 _signature) external returns (bool);

    /// @notice Checks if all signatures are ready for a given hash
    /// @param _txid The hash to check signatures for
    /// @return true if all signatures are present, false otherwise
    function checkAllSignaturesReady(bytes32 _txid) external view returns (bool);

    /// @notice Gets all partial signatures for a given hash
    /// @dev Returns signatures in the same order as committee members for Musig2 compatibility
    /// @param _txid The hash to get signatures for
    /// @return partialSignaturesData Array of signature data for all committee members
    /// @return missingSignatures Number of missing signatures
    /// @return missingNonces Number of missing nonces
    /// @return committeeId The committee ID for this signature collection
    function getPartialSignatures(bytes32 _txid)
        external
        view
        returns (
            SignatureData[] memory partialSignaturesData,
            uint8 missingSignatures,
            uint8 missingNonces,
            uint128 committeeId
        );

    /// @notice Initializes OperatorTake transaction id collection for a given accept peg-in transaction
    /// @dev Sets up the OperatorTake txid tracking structure for committee members
    /// @dev Can only be called by the PegManager
    /// @param _acceptPeginTxid The accept peg-in transaction id
    /// @param _committeeId The ID of the committee responsible for OperatorTake operations
    function initOperatorTakeTxids(bytes32 _acceptPeginTxid, uint128 _committeeId) external;

    /// @notice Adds a OperatorTake and OperatorWon transaction id for an operator
    /// @dev Only operators can add OperatorTake transaction id's
    /// @param _acceptPeginTxid The accept peg-in transaction id
    /// @param _takeTxid The OperatorTake transaction id to add
    function addOperatorTakeTxids(bytes32 _acceptPeginTxid, bytes32 _takeTxid, bytes32 _wonTxid) external;

    /// @notice Checks if all OperatorTake transaction id's are ready for a given accept peg-in transaction
    /// @param _acceptPeginTxid The accept peg-in transaction id to check
    /// @return true if all OperatorTake transaction id's are present, false otherwise
    function checkAllOperatorTakesHashesReady(bytes32 _acceptPeginTxid) external view returns (bool);

    /// @notice Gets all OperatorTake transaction data for a given accept peg-in transaction
    /// @param _acceptPeginTxid The accept peg-in transaction id
    /// @return Array of OperatorTake transaction data for all operators
    function getOperatorTakeData(bytes32 _acceptPeginTxid) external view returns (OperatorTakeData[] memory);

    /// @notice Gets the committee ID for a specific accept peg-in transaction id
    /// @param _acceptPeginTxid The accept peg-in transaction id
    /// @return The committee ID responsible for this accept peg-in
    function getCommitteeIdByAcceptPeginTxid(bytes32 _acceptPeginTxid) external view returns (uint128);

    // Events
    /// @notice Event emitted when a nonce is added by a committee member
    /// @param txid The txid being signed
    /// @param memberAddress The member's RSK address
    /// @param nonce The nonce provided by the member
    event NonceAdded(bytes32 indexed txid, address indexed memberAddress, bytes nonce);

    /// @notice Event emitted when all nonces are ready for a hash
    /// @param txid The txid for which all nonces are ready
    event AllNoncesReady(bytes32 indexed txid);

    /// @notice Event emitted when a signature is added by a committee member
    /// @param txid The txid being signed
    /// @param memberAddress The member's RSK address
    /// @param signature The signature provided by the member
    event SignatureAdded(bytes32 indexed txid, address indexed memberAddress, bytes32 signature);

    /// @notice Event emitted when all signatures are ready for a hash
    /// @param txid The txid for which all signatures are ready
    event AllSignaturesReady(bytes32 indexed txid);

    /// @notice Event emitted when OperatorTake and OperatorWon transaction id are added for a member
    /// @param acceptPeginTxid The accept peg-in transaction id
    /// @param memberAddress The member's address
    /// @param takeTxid The OperatorTake transaction id provided by the member
    /// @param wonTxid The OperatorWon transaction id provided by the member
    event OperatorTakeTxidsAdded(bytes32 acceptPeginTxid, address memberAddress, bytes32 takeTxid, bytes32 wonTxid);

    /// @notice Event emitted when all OperatorTake and OperatorWon transaction id's are added
    /// @param acceptPeginTxid The accept peg-in transaction id
    event AllOperatorTakeTxidsAdded(bytes32 acceptPeginTxid);

    // Errors
    /// @notice Thrown when the committee registry address is set to zero
    error InvalidZeroAddress();

    /// @notice Thrown when a txid to sign is not found
    /// @param txid The txid that was not found
    error TxidToSignNotFound(bytes32 txid);

    /// @notice Thrown when the nonce length is invalid
    /// @param actual The actual nonce length
    /// @param expected The expected nonce length (66 bytes)
    error InvalidNonceLength(uint256 actual, uint8 expected);

    /// @notice Thrown when a member has already added a nonce
    /// @param memberAddress The member's address
    /// @param nonce The nonce that was already added
    error MemberAlreadyAddedNonce(address memberAddress, bytes nonce);

    /// @notice Thrown when all nonces are not present
    /// @param txid The txid for which nonces are missing
    error AllNoncesAreNotPresent(bytes32 txid);

    /// @notice Thrown when a signature is invalid
    error InvalidSignature();

    /// @notice Thrown when a member has already signed
    /// @param memberAddress The member's address
    /// @param pegoutTxid The peg-out transaction id
    error MemberHasAlreadySigned(address memberAddress, bytes32 pegoutTxid);

    /// @notice Thrown when a member is not found
    /// @param memberAddress The member's address
    error MemberNotFound(address memberAddress);

    /// @notice Thrown when a member is not found in a committee
    /// @param committeeId The committee ID
    /// @param memberAddress The member's address
    error MemberNotFoundInCommittee(uint128 committeeId, address memberAddress);

    /// @notice Thrown when the hash to sign is invalid
    /// @param txid The invalid txid
    error InvalidTxidToSign(bytes32 txid);

    /// @notice Thrown when signatures are already initialized
    /// @param txid The txid for which signatures are already initialized
    error SignaturesAlreadyInitialized(bytes32 txid);

    /// @notice Thrown when the accept peg-in transaction id is invalid
    /// @param acceptPeginTxid The invalid accept peg-in transaction id
    error InvalidAcceptPeginTxid(bytes32 acceptPeginTxid);

    /// @notice Thrown when OperatorTake transaction id's are already initialized
    /// @param acceptPeginTxid The accept peg-in transaction id
    error OperatorTakeTxidsAlreadyInitialized(bytes32 acceptPeginTxid);

    /// @notice Thrown when an accept peg-in transaction id is not found
    /// @param acceptPeginTxid The accept peg-in transaction id that was not found
    error AcceptPeginTxidNotFound(bytes32 acceptPeginTxid);

    /// @notice Thrown when all OperatorTake transaction id's are already present
    /// @param acceptPeginTxid The accept peg-in transaction id
    error AllOperatorTakeTxidsAlreadyPresent(bytes32 acceptPeginTxid);

    /// @notice Thrown when a hash is invalid
    /// @param hash The invalid hash
    error InvalidHash(bytes32 hash);

    /// @notice Thrown when a member is not an operator
    /// @param committeeId The committee ID
    /// @param memberAddress The member's address
    error MemberIsNotOperator(uint128 committeeId, address memberAddress);

    /// @notice Thrown when a member has already added OperatorTake and OperatorWon transaction ids
    /// @param acceptPeginTxid The accept peg-in transaction id
    /// @param memberAddress The member's address
    /// @param takeTxid The OperatorTake transaction id that was already added
    /// @param wonTxid The OperatorWon transaction id that was already added
    error MemberAlreadyAddedOperatorTakeTxids(
        bytes32 acceptPeginTxid, address memberAddress, bytes32 takeTxid, bytes32 wonTxid
    );
}
