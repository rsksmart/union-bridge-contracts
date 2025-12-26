// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Constants} from "./libraries/Constants.sol";
import {
    ISignatureManager,
    Signatures,
    SignatureData,
    OperatorTakeTxids,
    OperatorTakeData
} from "./interfaces/ISignatureManager.sol";
import {CommitteeMember, ICommitteeRegistry, Role} from "./interfaces/ICommitteeRegistry.sol";
import {AccessControl} from "./AccessControl.sol";

/// @title Signature Manager
/// @notice Manages signatures for peg-in and peg-out operations
/// @dev Handles multi-signature operations for committee members using Musig2 protocol
/// @dev Manages both signature collection and OperatorTake transaction id collection
contract SignatureManager is ISignatureManager, AccessControl {
    /// @notice The committee registry contract that manages committee membership
    /// @dev Used to verify committee membership and get member information
    ICommitteeRegistry public committeeRegistry;

    // Signatures waiting for the committee to sign
    mapping(bytes32 hashToSign => Signatures signatures) internal committeeSignatures;
    mapping(bytes32 acceptPeginTxid => OperatorTakeTxids operatorTakeTxids) internal operatorTakeTxidsMap;

    /// @notice Initializes the SignatureManager contract
    /// @dev Sets up the committee registry and access control
    /// @dev Can only be called once during contract deployment
    /// @param _initialOwner The address that will be set as the initial owner
    /// @param _peginManager The address of the PeginManager contract
    /// @param _pegoutManager The address of the PegoutManager contract
    /// @param _committeeRegistry The address of the CommitteeRegistry contract
    function initialize(
        address _initialOwner,
        address _peginManager,
        address _pegoutManager,
        ICommitteeRegistry _committeeRegistry
    ) public initializer {
        if (address(_committeeRegistry) == address(0)) {
            revert CommitteeRegistryAddressZero();
        }
        committeeRegistry = _committeeRegistry;
        __AccessControl_init(_initialOwner, _peginManager, _pegoutManager);
    }

    function _isMemberInCommittee(uint128 _committeeId, address _memberAddress) internal view returns (bool) {
        return _getMemberRole(_committeeId, _memberAddress) != Role.NONE;
    }

    function _getMemberRole(uint128 _committeeId, address _memberAddress) internal view returns (Role) {
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
        address sender = _msgSender();
        // Check that nonce is 66 bytes
        if (_nonce.length != Constants.SIGNATURE_NONCE_LENGTH) {
            revert InvalidNonceLength(_nonce.length, Constants.SIGNATURE_NONCE_LENGTH);
        }

        Signatures storage signatures = _getSignatures(_hashToSign);
        // Check if the member is in the committee
        if (!_isMemberInCommittee(signatures.committeeId, sender)) {
            revert MemberNotFoundInCommittee(signatures.committeeId, sender);
        }

        SignatureData storage memberSignatureData = signatures.partialSignaturesData[sender];
        // Check if the member has already added a nonce
        if (memberSignatureData.nonce.length != 0) {
            revert MemberAlreadyAddedNonce(sender, _nonce);
        }
        // Store the  nonce for the member
        memberSignatureData.nonce = _nonce;
        emit NonceAdded(_hashToSign, sender, _nonce);

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
    /// @param _txid The hash that needs to be signed by the committee
    /// @param _signature The signature for the hash
    /// @return true if all signatures are now present, false otherwise
    function addMemberSignature(bytes32 _txid, bytes32 _signature) external returns (bool) {
        address sender = _msgSender();
        // Check if all nonces are present
        Signatures storage signatures = _getSignatures(_txid);
        if (signatures.missingNonces != 0) {
            revert AllNoncesAreNotPresent(_txid);
        }
        // Check if the signature is valid
        if (_signature == "") {
            revert InvalidSignature();
        }

        // Check if the member is in the committee
        if (!_isMemberInCommittee(signatures.committeeId, sender)) {
            revert MemberNotFoundInCommittee(signatures.committeeId, sender);
        }

        SignatureData storage memberSignatureData = signatures.partialSignaturesData[sender];
        // Check if the member has already added a signature
        if (memberSignatureData.signature != "") {
            revert MemberHasAlreadySigned(sender, _txid);
        }
        // Store the signature for the member
        memberSignatureData.signature = _signature;
        emit SignatureAdded(_txid, sender, _signature);

        // Check if all signatures are present
        signatures.missingSignatures -= 1;
        if (signatures.missingSignatures != 0) {
            return false;
        }
        emit AllSignaturesReady(_txid);
        return true;
    }

    /// @notice Checks if all signatures are ready for a given hash
    /// @param _txid The hash to check signatures for
    /// @return true if all signatures are present, false otherwise
    function checkAllSignaturesReady(bytes32 _txid) external view returns (bool) {
        Signatures storage signatures = _getSignatures(_txid);
        return signatures.committeeId != 0 && signatures.missingSignatures == 0;
    }

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
        )
    {
        Signatures storage signatures = _getSignatures(_txid);
        CommitteeMember[] memory members = committeeRegistry.getCommitteeMembers(signatures.committeeId);
        uint8 memberCount = uint8(members.length);
        partialSignaturesData = new SignatureData[](memberCount);
        // IMPORTANT: Musig2 requires the signatures and nonce to be in the same order when creating the partial and aggregated signatures
        for (uint256 i = 0; i < memberCount; i++) {
            partialSignaturesData[i] = signatures.partialSignaturesData[members[i].memberAddress];
        }
        return (partialSignaturesData, signatures.missingSignatures, signatures.missingNonces, signatures.committeeId);
    }

    function _getSignatures(bytes32 _txid) internal view returns (Signatures storage) {
        // Check if the signature hash exists
        // slither-disable-next-line incorrect-equality timestamp
        if (committeeSignatures[_txid].committeeId == 0) {
            revert HashToSignNotFound(_txid);
        }
        return committeeSignatures[_txid];
    }

    /// @notice Initializes signature collection for a given hash
    /// @dev Can only be called by the PegManager
    /// @param _txid The hash that needs to be signed
    /// @param _committeeId The committee ID that will sign the hash
    function initSignatures(bytes32 _txid, uint128 _committeeId) external onlyPegManager {
        // Check if the signature hash is not empty
        if (_txid == "") {
            revert InvalidHashToSign(_txid);
        }
        // Check if the signatures are already initialized
        Signatures storage signatures = committeeSignatures[_txid];
        if (signatures.committeeId != 0) {
            revert SignaturesAlreadyInitialized(_txid);
        }

        // Get the members
        CommitteeMember[] memory members = committeeRegistry.getCommitteeMembers(_committeeId);
        uint8 memberCount = uint8(members.length);

        // Initialize missing signatures counter
        signatures.missingSignatures = memberCount;
        signatures.missingNonces = memberCount;
        signatures.committeeId = _committeeId;
    }

    /// @notice Initializes OperatorTake transaction id collection for a given accept peg-in transaction
    /// @dev Can only be called by the PegManager
    /// @param _acceptPeginTxid The accept peg-in transaction id
    /// @param _committeeId The committee ID that will provide OperatorTake transaction id's
    function initOperatorTakeTxids(bytes32 _acceptPeginTxid, uint128 _committeeId) external onlyPegManager {
        // Check if the accept pegin tx id is not empty
        if (_acceptPeginTxid == bytes32(0)) {
            revert InvalidAcceptPeginTxid(_acceptPeginTxid);
        }

        // Check if the signatures are already initialized
        OperatorTakeTxids storage txids = operatorTakeTxidsMap[_acceptPeginTxid];
        if (txids.committeeId != 0) {
            revert OperatorTakeTxidsAlreadyInitialized(_acceptPeginTxid);
        }

        // Only operators should provide Take1 tx id's
        uint256 operatorsCount = 0;
        CommitteeMember[] memory members = committeeRegistry.getCommitteeMembers(_committeeId);
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].role == Role.OPERATOR) {
                operatorsCount++;
            }
        }

        // Initialize missing hashes counter
        txids.missingHashes = uint8(operatorsCount);
        txids.committeeId = _committeeId;
    }

    function _getOperatorTakeTxids(bytes32 _acceptPeginTxid) internal view returns (OperatorTakeTxids storage) {
        // slither-disable-next-line incorrect-equality timestamp
        if (operatorTakeTxidsMap[_acceptPeginTxid].committeeId == 0) {
            revert AcceptPeginTxidNotFound(_acceptPeginTxid);
        }
        return operatorTakeTxidsMap[_acceptPeginTxid];
    }

    /// @notice Adds a OperatorTake and OperatorWon transaction id for an operator
    /// @dev Only operators can add OperatorTake transaction id's
    /// @param _acceptPeginTxid The accept peg-in transaction id
    /// @param _takeTxid The OperatorTake transaction id to add
    function addOperatorTakeTxids(bytes32 _acceptPeginTxid, bytes32 _takeTxid, bytes32 _wonTxid) external {
        address sender = _msgSender();
        OperatorTakeTxids storage operatorTakeTxids = _getOperatorTakeTxids(_acceptPeginTxid);

        if (operatorTakeTxids.missingHashes == 0) {
            revert AllOperatorTakeTxidsAlreadyPresent(_acceptPeginTxid);
        }
        // Check if hash is valid
        if (_takeTxid == bytes32(0)) {
            revert InvalidHash(_takeTxid);
        }

        if (_wonTxid == bytes32(0)) {
            revert InvalidHash(_wonTxid);
        }

        Role role = _getMemberRole(operatorTakeTxids.committeeId, sender);

        // Check if the member is in the committee
        if (role == Role.NONE) {
            revert MemberNotFoundInCommittee(operatorTakeTxids.committeeId, sender);
        }

        // Only operators should add take 1 tx id's
        if (role != Role.OPERATOR) {
            revert MemberIsNotOperator(operatorTakeTxids.committeeId, sender);
        }

        if (operatorTakeTxids.takeTxids[sender] != bytes32(0) || operatorTakeTxids.wonTxids[sender] != bytes32(0)) {
            revert MemberAlreadyAddedOperatorTakeTxids(
                _acceptPeginTxid, sender, operatorTakeTxids.takeTxids[sender], operatorTakeTxids.wonTxids[sender]
            );
        }

        operatorTakeTxids.takeTxids[sender] = _takeTxid;
        operatorTakeTxids.wonTxids[sender] = _wonTxid;

        emit OperatorTakeTxidsAdded(_acceptPeginTxid, sender, _takeTxid, _wonTxid);

        operatorTakeTxids.missingHashes -= 1;
        if (operatorTakeTxids.missingHashes == 0) {
            emit AllOperatorTakeTxidsAdded(_acceptPeginTxid);
        }
    }

    /// @notice Checks if all OperatorTake transaction id's are ready for a given accept peg-in transaction
    /// @param _acceptPeginTxid The accept peg-in transaction id to check
    /// @return true if all OperatorTake transaction id's are present, false otherwise
    function checkAllOperatorTakesHashesReady(bytes32 _acceptPeginTxid) external view returns (bool) {
        OperatorTakeTxids storage operatorTakeTxids = _getOperatorTakeTxids(_acceptPeginTxid);
        return (operatorTakeTxids.missingHashes == 0);
    }

    /// @notice Gets all OperatorTake transaction data for a given accept peg-in transaction
    /// @param _acceptPeginTxid The accept peg-in transaction id
    /// @return Array of OperatorTake transaction data for all operators
    function getOperatorTakeData(bytes32 _acceptPeginTxid) external view returns (OperatorTakeData[] memory) {
        OperatorTakeTxids storage txids = _getOperatorTakeTxids(_acceptPeginTxid);
        uint256 operatorsCount = 0;
        CommitteeMember[] memory members = committeeRegistry.getCommitteeMembers(txids.committeeId);
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].role == Role.OPERATOR) {
                operatorsCount++;
            }
        }
        OperatorTakeData[] memory operatorTakeData = new OperatorTakeData[](operatorsCount);
        operatorsCount = 0;
        for (uint256 i = 0; i < members.length; i++) {
            address memberAddress = members[i].memberAddress;
            if (members[i].role == Role.OPERATOR) {
                operatorTakeData[operatorsCount].takeTxid = txids.takeTxids[memberAddress];
                operatorTakeData[operatorsCount].wonTxid = txids.wonTxids[memberAddress];
                operatorTakeData[operatorsCount].memberAddress = memberAddress;
                operatorsCount++;
            }
        }

        return operatorTakeData;
    }

    /// @notice Gets the committee ID for a given accept peg-in transaction id
    /// @param _acceptPeginTxid The accept peg-in transaction id
    /// @return The committee ID associated with this transaction id
    function getCommitteeIdByAcceptPeginTxid(bytes32 _acceptPeginTxid) external view returns (uint128) {
        return _getOperatorTakeTxids(_acceptPeginTxid).committeeId;
    }
}
