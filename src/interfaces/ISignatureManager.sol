// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

import {IAccessControl} from "./IAccessControl.sol";

struct SignatureData {
    bytes32 memberPublicKey;
    bytes32 signature;
    bytes nonce; // Should be 66 bytes
}

struct Signatures {
    SignatureData[] signaturesData;
    uint8 missingSignatures;
    uint8 missingNonces;
}

interface ISignatureManager is IAccessControl {
    function initSignatures(bytes32 _signatureHash, bytes32 _committeeKey) external;

    function addMemberNonce(bytes32 _signatureHash, bytes memory _nonce) external returns (bool);

    function addMemberSignature(bytes32 _signatureHash, bytes32 _signature) external returns (bool);

    function checkAllSignaturesReady(bytes32 _signatureHash) external view returns (bool);

    function getSignatures(bytes32 _signatureHash) external view returns (Signatures memory);

    event NonceAdded(bytes32 indexed signatureHash, bytes32 indexed memberPubKey, bytes nonce);
    event AllNoncesReady(bytes32 indexed signatureHash);
    event SignatureAdded(bytes32 indexed signatureHash, bytes32 indexed memberPubKey, bytes32 signature);
    event AllSignaturesReady(bytes32 indexed signatureHash);

    error CommitteeRegistryAddressZero();
    error SignatureHashNotFound(bytes32 signatureHash);
    error InvalidNonceLength(uint256 actual, uint8 expected);
    error MemberAlreadyAddedNonce(bytes32 memberPubKey, address memberAddress, bytes nonce);
    error AllNoncesAreNotPresent(bytes32 signatureHash);
    error InvalidSignature();
    error MemberHasAlreadySigned(bytes32 memberPubKey, address memberAddress, bytes32 pegOutTxHash);
    error MemberNotFound(address memberAddress);
    error MemberNotFoundInCommittee(bytes32 memberPubKey, bytes32 signatureHash);
    error InvalidSignatureHash(bytes32 signatureHash);
    error SignaturesAlreadyInitialized(bytes32 signatureHash);
    error InvalidCommittee(bytes32 committeeKey);
}
