// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Constants} from "./libraries/Constants.sol";
import {ISignatureManager, Signatures, SignatureData} from "./interfaces/ISignatureManager.sol";
import {Committee, CommitteeMember, ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {AccessControl} from "./AccessControl.sol";

/// @title SignatureManager
/// @notice Manages signatures for peg-in and peg-out operations
contract SignatureManager is ISignatureManager, AccessControl {
    ICommitteeRegistry public committeeRegistry;

    // Signatures waiting for the committee to sign
    mapping(bytes32 signatureHash => Signatures signatures) internal committeeSignatures;

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

    function _isMemberInCommittee(bytes32 _committeeKey, uint16 _memberIndex) internal view returns (bool) {
        CommitteeMember[] memory members = committeeRegistry.getCommitteeMember(_committeeKey);
        bool memberInCommittee = false;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].index == _memberIndex) {
                memberInCommittee = true;
                break;
            }
        }
        return memberInCommittee;
    }

    function addMemberNonce(bytes32 _signatureHash, bytes memory _nonce) external returns (bool) {
        // Check that nonce is 66 bytes
        if (_nonce.length != Constants.SIGNATURE_NONCE_LENGTH) {
            revert InvalidNonceLength(_nonce.length, Constants.SIGNATURE_NONCE_LENGTH);
        }

        // Get the sender's public key if it's a valid member and the signature data
        (uint16 memberIndex, bytes32 memberPubKey) = _getMemberIndex(msg.sender);
        Signatures storage signatures = _getSignatures(_signatureHash);
        // Check if the member is in the committee
        if (!_isMemberInCommittee(signatures.aggregatedKey, memberIndex)) {
            revert MemberNotFoundInCommittee(memberPubKey, msg.sender, _signatureHash);
        }

        SignatureData storage memberSignatureData = signatures.partialSignaturesData[memberIndex];
        // Check if the member has already added a nonce
        if (memberSignatureData.nonce.length != 0) {
            revert MemberAlreadyAddedNonce(memberPubKey, msg.sender, _nonce);
        }
        // Store the  nonce for the member
        memberSignatureData.nonce = _nonce;
        emit NonceAdded(_signatureHash, memberPubKey, _nonce);

        // Check if all nonces are present
        signatures.missingNonces -= 1;
        if (signatures.missingNonces != 0) {
            return false;
        }
        emit AllNoncesReady(_signatureHash);
        return true;
    }

    function addMemberSignature(bytes32 _signatureHash, bytes32 _signature) external returns (bool) {
        // Check if all nonces are present
        Signatures storage signatures = _getSignatures(_signatureHash);
        if (signatures.missingNonces != 0) {
            revert AllNoncesAreNotPresent(_signatureHash);
        }
        // Check if the signature is valid
        if (_signature == "") {
            revert InvalidSignature();
        }
        // Get the sender's public key if it's a valid member and the signature data
        (uint16 memberIndex, bytes32 memberPubKey) = _getMemberIndex(msg.sender);
        // Check if the member is in the committee
        if (!_isMemberInCommittee(signatures.aggregatedKey, memberIndex)) {
            revert MemberNotFoundInCommittee(memberPubKey, msg.sender, _signatureHash);
        }

        SignatureData storage memberSignatureData = signatures.partialSignaturesData[memberIndex];
        // Check if the member has already added a signature
        if (memberSignatureData.signature != "") {
            revert MemberHasAlreadySigned(memberPubKey, msg.sender, _signatureHash);
        }
        // Store the signature and nonce for the member
        memberSignatureData.signature = _signature;
        memberSignatureData.memberPublicKey = memberPubKey;
        emit SignatureAdded(_signatureHash, memberPubKey, _signature);

        // Check if all signatures are present
        signatures.missingSignatures -= 1;
        if (signatures.missingSignatures != 0) {
            return false;
        }
        emit AllSignaturesReady(_signatureHash);
        return true;
    }

    function checkAllSignaturesReady(bytes32 _signatureHash) external view returns (bool) {
        Signatures storage signatures = _getSignatures(_signatureHash);
        return signatures.aggregatedKey != "" && signatures.missingSignatures == 0;
    }

    function getPartialSignatures(bytes32 _signatureHash) external view returns (SignatureData[] memory) {
        Signatures storage signatures = _getSignatures(_signatureHash);
        CommitteeMember[] memory members = committeeRegistry.getCommitteeMember(signatures.aggregatedKey);
        uint8 memberCount = uint8(members.length);
        SignatureData[] memory partialSignaturesData = new SignatureData[](memberCount);
        // IMPORTANT: Musig2 requires the signatures and nonce to be in the same order when creating the partial and aggregated signatures
        for (uint256 i = 0; i < memberCount; i++) {
            partialSignaturesData[i] = signatures.partialSignaturesData[members[i].index];
            if (partialSignaturesData[i].memberPublicKey == "") {
                partialSignaturesData[i].memberPublicKey = committeeRegistry.getMemberPubKeyByIndex(members[i].index);
            }
        }
        return partialSignaturesData;
    }

    function getSignaturesStatus(bytes32 _signatureHash) external view returns (uint8, uint8, bytes32) {
        Signatures storage signatures = _getSignatures(_signatureHash);
        return (signatures.missingSignatures, signatures.missingNonces, signatures.aggregatedKey);
    }

    function _getSignatures(bytes32 _signatureHash) internal view returns (Signatures storage) {
        // Check if the signature hash exists
        if (committeeSignatures[_signatureHash].aggregatedKey == "") {
            revert SignatureHashNotFound(_signatureHash);
        }
        return committeeSignatures[_signatureHash];
    }

    function _getMemberIndex(address _memberAddress) internal view returns (uint16, bytes32) {
        // Check if caller is a valid member
        uint16 memberIndex = committeeRegistry.getMemberIndexByAddress(_memberAddress);
        bytes32 memberPubKey = committeeRegistry.getMemberPubKeyByIndex(memberIndex);

        return (memberIndex, memberPubKey);
    }

    function initSignatures(bytes32 _signatureHash, bytes32 _committeeKey) external onlyPegManager {
        // Check if the signature hash is not empty
        if (_signatureHash == "") {
            revert InvalidSignatureHash(_signatureHash);
        }
        // Check if the signatures are already initialized
        Signatures storage signatures = committeeSignatures[_signatureHash];
        if (signatures.aggregatedKey != "") {
            revert SignaturesAlreadyInitialized(_signatureHash);
        }

        // Get the members
        CommitteeMember[] memory members = committeeRegistry.getCommitteeMember(_committeeKey);
        uint8 memberCount = uint8(members.length);
        if (memberCount == 0) {
            revert InvalidCommittee(_committeeKey);
        }

        // Initialize missing signatures counter
        signatures.missingSignatures = memberCount;
        signatures.missingNonces = memberCount;
        signatures.aggregatedKey = _committeeKey;
    }
}
