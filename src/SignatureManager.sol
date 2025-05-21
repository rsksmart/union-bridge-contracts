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

    function addMemberNonce(bytes32 _signatureHash, bytes memory _nonce) external returns (bool) {
        // Check that nonce is 66 bytes
        if (_nonce.length != Constants.SIGNATURE_NONCE_LENGTH) {
            revert InvalidNonceLength(_nonce.length, Constants.SIGNATURE_NONCE_LENGTH);
        }

        // Get the sender's public key if it's a valid member and the signature data
        bytes32 memberPubKey = getMemberPubKey();
        SignatureData storage memberSignatureData = getMemberSignatureData(_signatureHash, memberPubKey);
        // Check if the member has already added a nonce
        if (memberSignatureData.nonce.length != 0) {
            revert MemberAlreadyAddedNonce(memberPubKey, msg.sender, memberSignatureData.nonce);
        }
        // Store the  nonce for the member
        memberSignatureData.nonce = _nonce;
        emit NonceAdded(_signatureHash, memberPubKey, _nonce);

        // Check if all nonces are present
        committeeSignatures[_signatureHash].missingNonces -= 1;
        if (committeeSignatures[_signatureHash].missingNonces != 0) {
            return false;
        }
        emit AllNoncesReady(_signatureHash);
        return true;
    }

    function addMemberSignature(bytes32 _signatureHash, bytes32 _signature) external returns (bool) {
        // Check if all nonces are present
        if (committeeSignatures[_signatureHash].missingNonces != 0) {
            revert AllNoncesAreNotPresent(_signatureHash);
        }
        // Check if the signature is valid
        if (_signature == "") {
            revert InvalidSignature();
        }
        // Get the sender's public key if it's a valid member and the signature data
        bytes32 memberPubKey = getMemberPubKey();
        SignatureData storage memberSignatureData = getMemberSignatureData(_signatureHash, memberPubKey);
        // Check if the member has already added a signature
        if (memberSignatureData.signature != "") {
            revert MemberHasAlreadySigned(memberPubKey, msg.sender, _signatureHash);
        }
        // Store the signature and nonce for the member
        memberSignatureData.signature = _signature;
        emit SignatureAdded(_signatureHash, memberPubKey, _signature);

        // Check if all signatures are present
        committeeSignatures[_signatureHash].missingSignatures -= 1;
        if (committeeSignatures[_signatureHash].missingSignatures != 0) {
            return false;
        }
        emit AllSignaturesReady(_signatureHash);
        return true;
    }

    function checkAllSignaturesReady(bytes32 _signatureHash) external view returns (bool) {
        return _getSignatures(_signatureHash).missingSignatures == 0;
    }

    function getSignatures(bytes32 _signatureHash) external view returns (Signatures memory) {
        return _getSignatures(_signatureHash);
    }

    function _getSignatures(bytes32 _signatureHash) internal view returns (Signatures storage) {
        // Check if the signature hash exists
        if (committeeSignatures[_signatureHash].signaturesData.length == 0) {
            revert SignatureHashNotFound(_signatureHash);
        }
        return committeeSignatures[_signatureHash];
    }

    function getMemberSignatureData(bytes32 _signatureHash, bytes32 _memberPubKey)
        internal
        view
        returns (SignatureData storage)
    {
        SignatureData[] storage signaturesData = _getSignatures(_signatureHash).signaturesData;
        for (uint256 i = 0; i < signaturesData.length; i++) {
            if (signaturesData[i].memberPublicKey == _memberPubKey) {
                return signaturesData[i];
            }
        }
        revert MemberNotFoundInCommittee(_memberPubKey, _signatureHash);
    }

    function getMemberPubKey() internal view returns (bytes32) {
        // Check if caller is a valid member
        bytes32 memberPubKey = committeeRegistry.getMemberPubKeyByAddress(msg.sender);
        if (memberPubKey == "") {
            revert MemberNotFound(msg.sender);
        }
        return memberPubKey;
    }

    function initSignatures(bytes32 _signatureHash, bytes32 _committeeKey) external onlyPegManager {
        // Check if the signature hash is not empty
        if (_signatureHash == "") {
            revert InvalidSignatureHash(_signatureHash);
        }
        // Check if the signatures are already initialized
        Signatures storage signatures = committeeSignatures[_signatureHash];
        if (signatures.signaturesData.length != 0) {
            revert SignaturesAlreadyInitialized(_signatureHash);
        }

        // Get the members
        CommitteeMember[] memory members = committeeRegistry.getCommitteeMember(_committeeKey);
        if (members.length == 0) {
            revert InvalidCommittee(_committeeKey);
        }

        // Initialize the signatures for each member
        // IMPORTANT: Musig2 requires the signatures and nonce to be in the same order when creating the partial and aggregated signatures
        for (uint256 i = 0; i < members.length; i++) {
            signatures.signaturesData.push(
                SignatureData({
                    memberPublicKey: committeeRegistry.getMemberPubKeyByIndex(members[i].index),
                    signature: "",
                    nonce: ""
                })
            );
        }
        // Initialize missing signatures counter
        signatures.missingSignatures = uint8(members.length);
        signatures.missingNonces = uint8(members.length);
    }
}
