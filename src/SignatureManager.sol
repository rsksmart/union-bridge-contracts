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
import {BaseProxy} from "./BaseProxy.sol";
import {IAccessManager} from "./interfaces/IAccessManager.sol";

/// @title Signature Manager
/// @notice Manages signatures for peg-in and peg-out operations
/// @dev Handles multi-signature operations for committee members using Musig2 protocol
/// @dev Manages both signature collection and OperatorTake transaction id collection
contract SignatureManager is ISignatureManager, BaseProxy {
    /// @notice The committee registry contract that manages committee membership
    /// @dev Used to verify committee membership and get member information
    ICommitteeRegistry public committeeRegistry;
    /// @notice The access manager contract that manages access control
    /// @dev Used to check access control for sensitive operations
    IAccessManager public accessManager;

    // Signatures waiting for the committee to sign
    mapping(bytes32 txid => Signatures signatures) internal committeeSignatures;
    mapping(bytes32 acceptPeginTxid => OperatorTakeTxids operatorTakeTxids) internal operatorTakeTxidsMap;

    /// @notice Initializes the SignatureManager contract
    /// @dev Sets up the committee registry and access control
    /// @dev Can only be called once during contract deployment
    /// @param _initialOwner The address that will be set as the initial owner
    /// @param _accessManager The address of the AccessManager contract
    /// @param _committeeRegistry The address of the CommitteeRegistry contract
    function initialize(address _initialOwner, IAccessManager _accessManager, ICommitteeRegistry _committeeRegistry)
        public
        initializer
    {
        if (address(_accessManager) == address(0) || address(_committeeRegistry) == address(0)) {
            revert InvalidZeroAddress();
        }
        accessManager = _accessManager;
        committeeRegistry = _committeeRegistry;
        __BaseProxy_init(_initialOwner);
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

    /// @inheritdoc ISignatureManager
    function addMemberNonce(bytes32 _txid, bytes memory _nonce) external returns (bool) {
        address sender = _msgSender();
        // Check that nonce is 66 bytes
        if (_nonce.length != Constants.SIGNATURE_NONCE_LENGTH) {
            revert InvalidNonceLength(_nonce.length, Constants.SIGNATURE_NONCE_LENGTH);
        }

        Signatures storage signatures = _getSignatures(_txid);
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
        emit NonceAdded(_txid, sender, _nonce);

        // Check if all nonces are present
        signatures.missingNonces -= 1;
        if (signatures.missingNonces != 0) {
            return false;
        }
        emit AllNoncesReady(_txid);
        return true;
    }

    /// @inheritdoc ISignatureManager
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

    /// @inheritdoc ISignatureManager
    function checkAllSignaturesReady(bytes32 _txid) external view returns (bool) {
        Signatures storage signatures = _getSignatures(_txid);
        return signatures.committeeId != 0 && signatures.missingSignatures == 0;
    }

    /// @inheritdoc ISignatureManager
    function getPartialSignatures(bytes32 _txid)
        external
        view
        returns (SignatureData[] memory partialSignaturesData, uint8 missingNonces, uint128 committeeId)
    {
        Signatures storage signatures = _getSignatures(_txid);
        CommitteeMember[] memory members = committeeRegistry.getCommitteeMembers(signatures.committeeId);
        uint8 memberCount = uint8(members.length);
        partialSignaturesData = new SignatureData[](memberCount);
        // IMPORTANT: Musig2 requires the signatures and nonce to be in the same order when creating the partial and aggregated signatures
        for (uint256 i = 0; i < memberCount; i++) {
            partialSignaturesData[i] = signatures.partialSignaturesData[members[i].memberAddress];
        }
        return (partialSignaturesData, signatures.missingNonces, signatures.committeeId);
    }

    function _getSignatures(bytes32 _txid) internal view returns (Signatures storage) {
        // Check if the signature hash exists
        // slither-disable-next-line incorrect-equality timestamp
        if (committeeSignatures[_txid].committeeId == 0) {
            revert TxidToSignNotFound(_txid);
        }
        return committeeSignatures[_txid];
    }

    /// @inheritdoc ISignatureManager
    function initSignatures(bytes32 _txid, uint128 _committeeId) external {
        // Verify that the caller has permission to initialize signatures
        accessManager.canInitSignatures(_msgSender());

        // Check if the signature hash is not empty
        if (_txid == "") {
            revert InvalidTxidToSign(_txid);
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

    /// @inheritdoc ISignatureManager
    function initOperatorTakeTxids(bytes32 _acceptPeginTxid, uint128 _committeeId) external {
        // Verify that the caller has permission to initialize operator take txids
        accessManager.canInitOperatorTakeTxids(_msgSender());

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

    /// @inheritdoc ISignatureManager
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

    /// @inheritdoc ISignatureManager
    function checkAllOperatorTakesHashesReady(bytes32 _acceptPeginTxid) external view returns (bool) {
        OperatorTakeTxids storage operatorTakeTxids = _getOperatorTakeTxids(_acceptPeginTxid);
        return (operatorTakeTxids.missingHashes == 0);
    }

    /// @inheritdoc ISignatureManager
    function getMissingOperatorTakeHashes(bytes32 _acceptPeginTxid) external view returns (uint8) {
        return _getOperatorTakeTxids(_acceptPeginTxid).missingHashes;
    }

    /// @inheritdoc ISignatureManager
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

    /// @inheritdoc ISignatureManager
    function getCommitteeIdByAcceptPeginTxid(bytes32 _acceptPeginTxid) external view returns (uint128) {
        return _getOperatorTakeTxids(_acceptPeginTxid).committeeId;
    }
}
