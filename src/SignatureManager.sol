// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Constants} from "./libraries/Constants.sol";
import {
    ISignatureManager, Signatures, SignatureData, Take1TxHashes, Take1Data
} from "./interfaces/ISignatureManager.sol";
import {Committee, CommitteeMember, ICommitteeRegistry, Role} from "./interfaces/ICommitteeRegistry.sol";
import {AccessControl} from "./AccessControl.sol";

/// @title Signature Manager
/// @notice Manages signatures for peg-in and peg-out operations
/// @dev Handles multi-signature operations for committee members using Musig2 protocol
/// @dev Manages both signature collection and Take1 transaction hash collection
contract SignatureManager is ISignatureManager, AccessControl {
    /// @notice The committee registry contract that manages committee membership
    /// @dev Used to verify committee membership and get member information
    ICommitteeRegistry public committeeRegistry;

    // Signatures waiting for the committee to sign
    mapping(bytes32 hashToSign => Signatures signatures) internal committeeSignatures;
    mapping(bytes32 acceptPeginTxHash => Take1TxHashes take1TxHashes) internal take1TxHashesMap;

    /// @notice Initializes the SignatureManager contract
    /// @dev Sets up the committee registry and access control
    /// @dev Can only be called once during contract deployment
    /// @param _initialOwner The address that will be set as the initial owner
    /// @param _pegManager The address of the PegManager contract
    /// @param _committeeRegistry The address of the CommitteeRegistry contract
    function initialize(address _initialOwner, address _pegManager, ICommitteeRegistry _committeeRegistry)
        public
        initializer
    {
        if (address(_committeeRegistry) == address(0)) {
            revert CommitteeRegistryAddressZero();
        }
        committeeRegistry = _committeeRegistry;
        __AccessControl_init(_initialOwner, _pegManager);
    }

    function _isMemberInCommittee(uint256 _committeeId, address _memberAddress) internal view returns (bool) {
        return _getMemberRole(_committeeId, _memberAddress) != Role.NONE;
    }

    function _getMemberRole(uint256 _committeeId, address _memberAddress) internal view returns (Role) {
        CommitteeMember[] memory members = committeeRegistry.getCommitteeMembers(_committeeId);
        Role role = Role.NONE;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].memberAddress == _memberAddress) {
                role = members[i].role;
                break;
            }
        }
        return role;
    }

    /// @notice Adds a nonce for a committee member to the signature collection
    /// @dev Nonces are required for Musig2 signature aggregation
    /// @param _hashToSign The hash that needs to be signed by the committee
    /// @param _nonce The 66-byte nonce for the Musig2 protocol
    /// @return true if all nonces are now present, false otherwise
    function addMemberNonce(bytes32 _hashToSign, bytes memory _nonce) external returns (bool) {
        // Check that nonce is 66 bytes
        if (_nonce.length != Constants.SIGNATURE_NONCE_LENGTH) {
            revert InvalidNonceLength(_nonce.length, Constants.SIGNATURE_NONCE_LENGTH);
        }

        Signatures storage signatures = _getSignatures(_hashToSign);
        // Check if the member is in the committee
        if (!_isMemberInCommittee(signatures.committeeId, msg.sender)) {
            revert MemberNotFoundInCommittee(signatures.committeeId, msg.sender);
        }

        SignatureData storage memberSignatureData = signatures.partialSignaturesData[msg.sender];
        // Check if the member has already added a nonce
        if (memberSignatureData.nonce.length != 0) {
            revert MemberAlreadyAddedNonce(msg.sender, _nonce);
        }
        // Store the  nonce for the member
        memberSignatureData.nonce = _nonce;
        emit NonceAdded(_hashToSign, msg.sender, _nonce);

        // Check if all nonces are present
        signatures.missingNonces -= 1;
        if (signatures.missingNonces != 0) {
            return false;
        }
        emit AllNoncesReady(_hashToSign);
        return true;
    }

    /// @notice Adds a signature for a committee member to the signature collection
    /// @dev Signatures can only be added after all nonces are present
    /// @param _hashToSign The hash that needs to be signed by the committee
    /// @param _signature The signature for the hash
    /// @return true if all signatures are now present, false otherwise
    function addMemberSignature(bytes32 _hashToSign, bytes32 _signature) external returns (bool) {
        // Check if all nonces are present
        Signatures storage signatures = _getSignatures(_hashToSign);
        if (signatures.missingNonces != 0) {
            revert AllNoncesAreNotPresent(_hashToSign);
        }
        // Check if the signature is valid
        if (_signature == "") {
            revert InvalidSignature();
        }

        // Check if the member is in the committee
        if (!_isMemberInCommittee(signatures.committeeId, msg.sender)) {
            revert MemberNotFoundInCommittee(signatures.committeeId, msg.sender);
        }

        SignatureData storage memberSignatureData = signatures.partialSignaturesData[msg.sender];
        // Check if the member has already added a signature
        if (memberSignatureData.signature != "") {
            revert MemberHasAlreadySigned(msg.sender, _hashToSign);
        }
        // Store the signature for the member
        memberSignatureData.signature = _signature;
        emit SignatureAdded(_hashToSign, msg.sender, _signature);

        // Check if all signatures are present
        signatures.missingSignatures -= 1;
        if (signatures.missingSignatures != 0) {
            return false;
        }
        emit AllSignaturesReady(_hashToSign);
        return true;
    }

    /// @notice Checks if all signatures are ready for a given hash
    /// @param _hashToSign The hash to check signatures for
    /// @return true if all signatures are present, false otherwise
    function checkAllSignaturesReady(bytes32 _hashToSign) external view returns (bool) {
        Signatures storage signatures = _getSignatures(_hashToSign);
        return signatures.committeeId != 0 && signatures.missingSignatures == 0;
    }

    /// @notice Gets all partial signatures for a given hash
    /// @dev Returns signatures in the same order as committee members for Musig2 compatibility
    /// @param _hashToSign The hash to get signatures for
    /// @return Array of signature data for all committee members
    function getPartialSignatures(bytes32 _hashToSign) external view returns (SignatureData[] memory) {
        Signatures storage signatures = _getSignatures(_hashToSign);
        CommitteeMember[] memory members = committeeRegistry.getCommitteeMembers(signatures.committeeId);
        uint8 memberCount = uint8(members.length);
        SignatureData[] memory partialSignaturesData = new SignatureData[](memberCount);
        // IMPORTANT: Musig2 requires the signatures and nonce to be in the same order when creating the partial and aggregated signatures
        for (uint256 i = 0; i < memberCount; i++) {
            partialSignaturesData[i] = signatures.partialSignaturesData[members[i].memberAddress];
        }
        return partialSignaturesData;
    }

    /// @notice Gets the status of signatures for a given hash
    /// @param _hashToSign The hash to get status for
    /// @return missingSignatures Number of missing signatures
    /// @return missingNonces Number of missing nonces
    /// @return committeeId The committee ID for this signature collection
    function getSignaturesStatus(bytes32 _hashToSign) external view returns (uint8, uint8, uint256) {
        Signatures storage signatures = _getSignatures(_hashToSign);
        return (signatures.missingSignatures, signatures.missingNonces, signatures.committeeId);
    }

    function _getSignatures(bytes32 _hashToSign) internal view returns (Signatures storage) {
        // Check if the signature hash exists
        // slither-disable-next-line incorrect-equality timestamp
        if (committeeSignatures[_hashToSign].committeeId == 0) {
            revert HashToSignNotFound(_hashToSign);
        }
        return committeeSignatures[_hashToSign];
    }

    /// @notice Initializes signature collection for a given hash
    /// @dev Can only be called by the PegManager
    /// @param _hashToSign The hash that needs to be signed
    /// @param _committeeId The committee ID that will sign the hash
    function initSignatures(bytes32 _hashToSign, uint256 _committeeId) external onlyPegManager {
        // Check if the signature hash is not empty
        if (_hashToSign == "") {
            revert InvalidHashToSign(_hashToSign);
        }
        // Check if the signatures are already initialized
        Signatures storage signatures = committeeSignatures[_hashToSign];
        if (signatures.committeeId != 0) {
            revert SignaturesAlreadyInitialized(_hashToSign);
        }

        // Get the members
        CommitteeMember[] memory members = committeeRegistry.getCommitteeMembers(_committeeId);
        uint8 memberCount = uint8(members.length);

        // Initialize missing signatures counter
        signatures.missingSignatures = memberCount;
        signatures.missingNonces = memberCount;
        signatures.committeeId = _committeeId;
    }

    /// @notice Initializes Take1 transaction hash collection for a given accept peg-in transaction
    /// @dev Can only be called by the PegManager
    /// @param _acceptPeginTxHash The accept peg-in transaction hash
    /// @param _committeeId The committee ID that will provide Take1 transaction hashes
    function initTake1TxHashes(bytes32 _acceptPeginTxHash, uint256 _committeeId) external onlyPegManager {
        // Check if the accept pegin tx hash is not empty
        if (_acceptPeginTxHash == bytes32(0)) {
            revert InvalidAcceptPeginTxHash(_acceptPeginTxHash);
        }

        // Check if the signatures are already initialized
        Take1TxHashes storage txHashes = take1TxHashesMap[_acceptPeginTxHash];
        if (txHashes.committeeId != 0) {
            revert Take1TxHashesAlreadyInitialized(_acceptPeginTxHash);
        }

        // Only operators should provide Take1 tx hashes
        uint256 operatorsCount = 0;
        CommitteeMember[] memory members = committeeRegistry.getCommitteeMembers(_committeeId);
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].role == Role.OPERATOR) {
                operatorsCount++;
            }
        }

        // Initialize missing hashes counter
        txHashes.missingHashes = uint8(operatorsCount);
        txHashes.committeeId = _committeeId;
    }

    function _getTake1TxHashes(bytes32 _acceptPeginTxHash) internal view returns (Take1TxHashes storage) {
        // slither-disable-next-line incorrect-equality timestamp
        if (take1TxHashesMap[_acceptPeginTxHash].committeeId == 0) {
            revert AcceptPeginTxHashNotFound(_acceptPeginTxHash);
        }
        return take1TxHashesMap[_acceptPeginTxHash];
    }

    /// @notice Adds a Take1 transaction hash for an operator
    /// @dev Only operators can add Take1 transaction hashes
    /// @param _acceptPeginTxHash The accept peg-in transaction hash
    /// @param _hash The Take1 transaction hash to add
    function addTake1TxHash(bytes32 _acceptPeginTxHash, bytes32 _hash) external {
        Take1TxHashes storage take1TxHashes = _getTake1TxHashes(_acceptPeginTxHash);

        if (take1TxHashes.missingHashes == 0) {
            revert AllTake1TxHashesAlreadyPresent(_acceptPeginTxHash);
        }
        // Check if hash is valid
        if (_hash == bytes32(0)) {
            revert InvalidHash(_hash);
        }

        Role role = _getMemberRole(take1TxHashes.committeeId, msg.sender);

        // Check if the member is in the committee
        if (role == Role.NONE) {
            revert MemberNotFoundInCommittee(take1TxHashes.committeeId, msg.sender);
        }

        // Only operators should add take 1 tx hashes
        if (role != Role.OPERATOR) {
            revert MemberIsNotOperator(take1TxHashes.committeeId, msg.sender);
        }

        if (take1TxHashes.txHashes[msg.sender] != bytes32(0)) {
            revert MemberAlreadyAddedTake1TxHash(_acceptPeginTxHash, msg.sender, _hash);
        }

        take1TxHashes.txHashes[msg.sender] = _hash;
        emit Take1TxHashAdded(_acceptPeginTxHash, msg.sender, _hash);

        take1TxHashes.missingHashes -= 1;
        if (take1TxHashes.missingHashes == 0) {
            emit AllTake1TxHashesAdded(_acceptPeginTxHash);
        }
    }

    /// @notice Checks if all Take1 transaction hashes are ready for a given accept peg-in transaction
    /// @param _acceptPeginTxHash The accept peg-in transaction hash to check
    /// @return true if all Take1 transaction hashes are present, false otherwise
    function checkAllTake1HashesReady(bytes32 _acceptPeginTxHash) external view returns (bool) {
        Take1TxHashes storage take1TxHashes = _getTake1TxHashes(_acceptPeginTxHash);
        return (take1TxHashes.missingHashes == 0);
    }

    /// @notice Gets all Take1 transaction data for a given accept peg-in transaction
    /// @param _acceptPeginTxHash The accept peg-in transaction hash
    /// @return Array of Take1 transaction data for all operators
    function getTake1Data(bytes32 _acceptPeginTxHash) external view returns (Take1Data[] memory) {
        Take1TxHashes storage take1TxHashes = _getTake1TxHashes(_acceptPeginTxHash);
        uint256 operatorsCount = 0;
        CommitteeMember[] memory members = committeeRegistry.getCommitteeMembers(take1TxHashes.committeeId);
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].role == Role.OPERATOR) {
                operatorsCount++;
            }
        }
        Take1Data[] memory take1Data = new Take1Data[](operatorsCount);
        operatorsCount = 0;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].role == Role.OPERATOR) {
                take1Data[operatorsCount].txHash = take1TxHashes.txHashes[members[i].memberAddress];
                take1Data[operatorsCount].memberAddress = members[i].memberAddress;
                operatorsCount++;
            }
        }

        return take1Data;
    }

    /// @notice Gets the committee ID for a given accept peg-in transaction hash
    /// @param _acceptPeginTxHash The accept peg-in transaction hash
    /// @return The committee ID associated with this transaction hash
    function getCommitteeIdByAcceptPeginTxHash(bytes32 _acceptPeginTxHash) external view returns (uint256) {
        Take1TxHashes storage take1TxHashes = _getTake1TxHashes(_acceptPeginTxHash);
        return take1TxHashes.committeeId;
    }
}
