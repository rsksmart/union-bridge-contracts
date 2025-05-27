// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

import {IAccessControl} from "./IAccessControl.sol";

struct SignatureData {
    bytes32 memberPublicKey;
    bytes32 signature;
    bytes nonce; // Should be 66 bytes
}

struct Signatures {
    mapping(uint256 memberIndex => SignatureData) partialSignaturesData;
    uint8 missingSignatures;
    uint8 missingNonces;
    bytes32 aggregatedKey;
    uint256 timestamp;
    uint256 committeeId;
}

interface ISignatureManager is IAccessControl {
    function initSignatures(bytes32 _hashToSign, uint256 _committeeId) external;

    function addMemberNonce(bytes32 _hashToSign, bytes memory _nonce) external returns (bool);

    function addMemberSignature(bytes32 _hashToSign, bytes32 _signature) external returns (bool);

    function checkAllSignaturesReady(bytes32 _hashToSign) external view returns (bool);

    function getPartialSignatures(bytes32 _hashToSign) external view returns (SignatureData[] memory);

    function getSignaturesStatus(bytes32 _hashToSign)
        external
        view
        returns (uint8 missingSignatures, uint8 missingNonces, uint256 committeeId);

    event NonceAdded(bytes32 indexed hashToSign, bytes32 indexed memberPubKey, bytes nonce);
    event AllNoncesReady(bytes32 indexed hashToSign);
    event SignatureAdded(bytes32 indexed hashToSign, bytes32 indexed memberPubKey, bytes32 signature);
    event AllSignaturesReady(bytes32 indexed hashToSign);

    error CommitteeRegistryAddressZero();
    error HashToSignNotFound(bytes32 hashToSign);
    error InvalidNonceLength(uint256 actual, uint8 expected);
    error MemberAlreadyAddedNonce(bytes32 memberPubKey, address memberAddress, bytes nonce);
    error AllNoncesAreNotPresent(bytes32 hashToSign);
    error InvalidSignature();
    error MemberHasAlreadySigned(bytes32 memberPubKey, address memberAddress, bytes32 pegOutTxHash);
    error MemberNotFound(address memberAddress);
    error MemberNotFoundInCommittee(bytes32 memberPubKey, address memberAddress, bytes32 hashToSign);
    error InvalidHashToSign(bytes32 hashToSign);
    error SignaturesAlreadyInitialized(bytes32 hashToSign);
    error InvalidCommittee(uint256 committeeId);
}
