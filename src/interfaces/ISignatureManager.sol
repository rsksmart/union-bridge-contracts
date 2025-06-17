// SPDX-License-Identifier: UNKNOWN
pragma solidity ^0.8.20;

import {IAccessControl} from "./IAccessControl.sol";

struct SignatureData {
    bytes32 memberPublicKey;
    bytes32 signature;
    bytes nonce; // Should be 66 bytes
}

struct Signatures {
    mapping(address memberAddress => SignatureData) partialSignaturesData;
    uint8 missingSignatures;
    uint8 missingNonces;
    uint256 timestamp;
    uint256 committeeId;
}

struct Take1Data {
    bytes32 txHash;
    address memberAddress;
}

struct Take1TxHashes {
    mapping(address memberAddress => bytes32 take1TxHash) txHashes;
    uint8 missingHashes;
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

    function initTake1TxHashes(bytes32 _acceptPeginTxHash, uint256 _committeeId) external;
    function addTake1TxHash(bytes32 _acceptPeginTxHash, bytes32 _txHash) external;
    function checkAllTake1HashesReady(bytes32 _acceptPeginTxHash) external view returns (bool);
    function getTake1Data(bytes32 _acceptPeginTxHash) external view returns (Take1Data[] memory);
    function getCommitteeIdByAcceptPeginTxHash(bytes32 _acceptPeginTxHash) external view returns (uint256);

    event NonceAdded(bytes32 indexed hashToSign, bytes32 indexed memberPubKey, bytes nonce);
    event AllNoncesReady(bytes32 indexed hashToSign);
    event SignatureAdded(bytes32 indexed hashToSign, bytes32 indexed memberPubKey, bytes32 signature);
    event AllSignaturesReady(bytes32 indexed hashToSign);
    event Take1TxHashAdded(bytes32 acceptPeginTxHash, address memberAddress, bytes32 hash);
    event AllTake1TxHashesAdded(bytes32 acceptPeginTxHash);

    error CommitteeRegistryAddressZero();
    error HashToSignNotFound(bytes32 hashToSign);
    error InvalidNonceLength(uint256 actual, uint8 expected);
    error MemberAlreadyAddedNonce(bytes32 memberPubKey, address memberAddress, bytes nonce);
    error AllNoncesAreNotPresent(bytes32 hashToSign);
    error InvalidSignature();
    error MemberHasAlreadySigned(bytes32 memberPubKey, address memberAddress, bytes32 pegoutTxHash);
    error MemberNotFound(address memberAddress);
    error MemberNotFoundInCommittee(uint256 committeeId, address memberAddress);
    error InvalidHashToSign(bytes32 hashToSign);
    error SignaturesAlreadyInitialized(bytes32 hashToSign);
    error InvalidAcceptPeginTxHash(bytes32 acceptPeginTxHash);
    error Take1TxHashesAlreadyInitialized(bytes32 acceptPeginTxHash);
    error AcceptPeginTxHashNotFound(bytes32 acceptPeginTxHash);
    error AllTake1TxHashesAlreadyPresent(bytes32 acceptPeginTxHash);
    error InvalidHash(bytes32 hash);
    error MemberIsNotOperator(uint256 committeeId, address memberAddress);
    error MemberAlreadyAddedTake1TxHash(bytes32 acceptPeginTxHash, address memberAddress, bytes32 hash);
}
