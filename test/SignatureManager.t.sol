// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {
    ICommitteeRegistry,
    StreamDenomination,
    Role,
    CommitteeMember,
    PublicKeyRegistration
} from "src/interfaces/ICommitteeRegistry.sol";
import {IAccessControl} from "src/interfaces/IAccessControl.sol";
import {
    Signatures,
    SignatureData,
    ISignatureManager,
    OperatorTakeTxHashes,
    OperatorTakeData
} from "src/interfaces/ISignatureManager.sol";
import {Constants} from "src/libraries/Constants.sol";

contract TestSignatureManager is Test, HelperContract {
    uint64 internal setupStreamId;
    bytes32 constant ACCEPT_PEGIN_TX_HASH = hex"325bd7c332003b6f86b54cc1fa15429cc47124e5ec9c9900043ecbc61de38095";

    function setUp() external {
        runTestDeployScript();
        (, setupStreamId) = setup_completeCommittee();
    }

    // we only check the revert case since the success cases are being checked in the _addMemberSignaturePegout tests
    function test_checkAllSignaturesReady_Revert_PegoutRequestNotFound() external {
        // Arrange
        bytes32 hashToSign = 0x0000000000000000000000000000000000000000000000000000000000000001;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.HashToSignNotFound.selector, hashToSign));

        // Act
        signatureManager.checkAllSignaturesReady(hashToSign);
    }

    function test_addMemberNonce_Success() external {
        // Arrange
        bytes32 hashToSign = setup_initSignatures();
        // The nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        address committeeMember0adr = vm.addr(1);

        // Assert
        // We emit the event we expect to see.
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.NonceAdded(hashToSign, committeeMember0adr, nonce);

        // Act
        vm.prank(committeeMember0adr);
        bool allNoncesReady = signatureManager.addMemberNonce(hashToSign, nonce);

        // Assert
        assertEq(allNoncesReady, false, "Not all nonces should be ready at this point");
    }

    function test_addMemberNonce_Success_AllNoncesReady() external {
        // Arrange
        bytes32 hashToSign = setup_initSignatures();
        // The nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        setup_addMemberNonce_MultipleMembers(hashToSign, 0, registry.minCommitteeMembers() - 1);
        (hashToSign);
        uint256 lastMemberIndex = registry.minCommitteeMembers() - 1;
        address lastMemberAddress = vm.addr(lastMemberIndex + 1);

        // Assert
        // We emit the event we expect to see.
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.NonceAdded(hashToSign, lastMemberAddress, nonce);

        // We emit the event we expect to see.
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.AllNoncesReady(hashToSign);

        // Act
        vm.prank(lastMemberAddress);
        bool allNoncesReady = signatureManager.addMemberNonce(hashToSign, nonce);

        // Assert
        assertEq(allNoncesReady, true, "Not all nonces should be ready at this point");
    }

    function test_addMemberSignature_Success() external {
        // Arrange
        // Init signatures and add all nonces
        bytes32 hashToSign = setup_initSignatures();
        setup_addAllNonces(hashToSign);
        // The signature an nonce values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        uint256 memberIndex = 0;
        address committeeMember0adr = vm.addr(memberIndex + 1);

        // We emit the event we expect to see.
        // Assert
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.SignatureAdded(hashToSign, committeeMember0adr, signature);

        // Act
        vm.prank(committeeMember0adr);
        bool allSignaturesReady = signatureManager.addMemberSignature(hashToSign, signature);

        // Assert
        assertEq(allSignaturesReady, false, "Not all signatures should be ready at this point");
        (uint8 missingSignatures, uint8 missingNonces, uint256 committeeId) =
            signatureManager.getSignaturesStatus(hashToSign);
        assertEq(missingSignatures, registry.minCommitteeMembers() - 1, "missingSignatures should be equal to 1");
        assertEq(missingNonces, 0, "missingNonces should be equal to 1");
        assertEq(
            committeeId,
            COMMITTEE_ID_STREAM_1_PACKET_0,
            "committeeId should be equal to the committee id that was created initially"
        );

        SignatureData[] memory signatures = signatureManager.getPartialSignatures(hashToSign);
        assertEq(
            signatures.length,
            registry.minCommitteeMembers(),
            "signatures length should be equal to registry.minCommitteeMembers()"
        );

        CommitteeMember[] memory members = registry.getCommitteeMembers(committeeId);
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].memberAddress != committeeMember0adr) {
                assertEq(
                    signatures[i].signature,
                    bytes32(0),
                    "signatures[i].signature should be empty for members other than the one who signed"
                );
            } else {
                assertEq(
                    signatures[i].signature,
                    signature,
                    "signatures[i].signature should be equal to the signature added by the member"
                );
            }
        }
    }

    function test_addMemberSignature_Success_AllSignaturesReady() external {
        // Arrange
        // Init signatures and add all nonces
        bytes32 hashToSign = setup_initSignatures();
        setup_addAllNonces(hashToSign);
        // The signature an nonce values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        uint256 memberCount = registry.minCommitteeMembers();
        setup_addMemberSignature_MultipleMembers(hashToSign, 0, memberCount - 1);
        // Pub key and address are generated based on the member index + 1
        uint256 lastMemberIndex = registry.minCommitteeMembers() - 1;
        address lastMemberAddress = vm.addr(lastMemberIndex + 1);

        // Assert
        // We emit the event we expect to see.
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.SignatureAdded(hashToSign, lastMemberAddress, signature);

        // We emit the event we expect to see.
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.AllSignaturesReady(hashToSign);

        // Act
        vm.prank(lastMemberAddress);
        bool allSignaturesReady = signatureManager.addMemberSignature(hashToSign, signature);

        // Assert
        assertEq(allSignaturesReady, true, "Not all signatures should be ready at this point");
        (uint8 missingSignatures, uint8 missingNonces, uint256 committeeId) =
            signatureManager.getSignaturesStatus(hashToSign);
        assertEq(missingSignatures, 0, "missingSignatures should be equal to 0");
        assertEq(missingNonces, 0, "missingNonces should be equal to 0");
        assertEq(committeeId, COMMITTEE_ID_STREAM_1_PACKET_0, "aggregatedKey should be equal to the committee key");
        SignatureData[] memory signatures = signatureManager.getPartialSignatures(hashToSign);
        assertEq(
            signatures.length,
            registry.minCommitteeMembers(),
            "signatures length should be equal to registry.minCommitteeMembers()"
        );

        CommitteeMember[] memory members = registry.getCommitteeMembers(committeeId);
        for (uint256 i = 0; i < members.length; i++) {
            assertNotEq(signatures[i].signature, bytes32(0), "signatures[i].signature should not be empty");
        }
    }

    function test_addMemberNonce_Revert_HashToSignNotFound() external {
        // Arrange
        bytes32 hashToSign = 0x0000000000000000000000000000000000000000000000000000000000000001;

        // The signature an nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.HashToSignNotFound.selector, hashToSign));

        // Act
        vm.prank(vm.addr(1));
        signatureManager.addMemberNonce(hashToSign, nonce);
    }

    function test_addMemberSignature_Revert_HashToSignNotFound() external {
        // Arrange
        bytes32 hashToSign = 0x0000000000000000000000000000000000000000000000000000000000000001;
        address memberAddress = vm.addr(registry.minCommitteeMembers() + 1);
        // The signature an nonce values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.HashToSignNotFound.selector, hashToSign));

        // Act
        vm.prank(memberAddress);
        signatureManager.addMemberSignature(hashToSign, signature);
    }

    function test_addMemberNonce_Revert_MemberHasAlreadySigned() external {
        // Arrange
        // Init signatures
        bytes32 hashToSign = setup_initSignatures();
        // The nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        address committeeMember0adr = vm.addr(1);

        // First time adding the nonce
        vm.prank(committeeMember0adr);
        signatureManager.addMemberNonce(hashToSign, nonce);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ISignatureManager.MemberAlreadyAddedNonce.selector, committeeMember0adr, nonce)
        );

        // Act add nonce a second time with the same committee member
        vm.prank(committeeMember0adr);
        signatureManager.addMemberNonce(hashToSign, nonce);
    }

    function test_addMemberSignature_Revert_MemberHasAlreadySigned() external {
        // Init signatures and add all nonces
        bytes32 hashToSign = setup_initSignatures();
        setup_addAllNonces(hashToSign);
        // Arrange
        // The signature values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        address committeeMember0adr = vm.addr(1);

        // Sign the first time
        vm.prank(committeeMember0adr);
        signatureManager.addMemberSignature(hashToSign, signature);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ISignatureManager.MemberHasAlreadySigned.selector, committeeMember0adr, hashToSign)
        );

        // Act sign a second time with the same committee member
        vm.prank(committeeMember0adr);
        signatureManager.addMemberSignature(hashToSign, signature);
    }

    function test_addMemberNonce_Revert_MemberNotFoundInCommittee() external {
        // Arrange
        bytes32 hashToSign = setup_initSignatures();
        address nonCommitteeMember = vm.addr(registry.minCommitteeMembers() + 1);
        PublicKeyRegistration[] memory nonCommitteeMemberPubKeysRegistration =
            generatePublicKeysRegistration(uint256(uint160(nonCommitteeMember)));
        setup_applyToStream(
            StreamDenomination._0_01BTC, nonCommitteeMember, nonCommitteeMemberPubKeysRegistration, Role.OPERATOR
        );
        // The nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberNotFoundInCommittee.selector, COMMITTEE_ID_STREAM_1_PACKET_0, nonCommitteeMember
            )
        );

        // Act
        vm.prank(nonCommitteeMember);
        signatureManager.addMemberNonce(hashToSign, nonce);
    }

    function test_addMemberSignature_Revert_MemberNotFoundInCommittee() external {
        // Arrange
        // Init signatures and add all nonces
        bytes32 hashToSign = setup_initSignatures();
        setup_addAllNonces(hashToSign);

        address nonCommitteeMember = vm.addr(registry.minCommitteeMembers() + 1);
        PublicKeyRegistration[] memory nonCommitteeMemberPubKeysRegistration =
            generatePublicKeysRegistration(uint256(uint160(nonCommitteeMember)));
        setup_applyToStream(
            StreamDenomination._0_01BTC, nonCommitteeMember, nonCommitteeMemberPubKeysRegistration, Role.OPERATOR
        );
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberNotFoundInCommittee.selector, COMMITTEE_ID_STREAM_1_PACKET_0, nonCommitteeMember
            )
        );

        // Act
        vm.prank(nonCommitteeMember);
        signatureManager.addMemberSignature(hashToSign, signature);
    }

    function test_addMemberSignature_Revert_InvalidNonceLength() external {
        bytes32 hashToSign = setup_initSignatures();

        // Arrange
        // The signature an nonce values are dummy values
        bytes memory nonce =
            hex"fff8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        address memberAddress = vm.addr(1);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.InvalidNonceLength.selector, nonce.length, Constants.SIGNATURE_NONCE_LENGTH
            )
        );

        // Act
        vm.prank(memberAddress);
        signatureManager.addMemberNonce(hashToSign, nonce);
    }

    function test_initSignatures_Success() external {
        // Arrange
        uint8 committeeMemberCount = uint8(registry.minCommitteeMembers());
        bytes32 hashToSign = 0x1000000000000000000000000000000000000000000000000000000000000001;

        // Act
        vm.prank(address(pm));
        signatureManager.initSignatures(hashToSign, COMMITTEE_ID_STREAM_1_PACKET_0);

        // Assert
        (uint8 missingSignatures, uint8 missingNonces,) = signatureManager.getSignaturesStatus(hashToSign);
        assertEq(
            missingSignatures, committeeMemberCount, "missingSignatures should be equal to the committee member count"
        );
        assertEq(missingNonces, committeeMemberCount, "missingNonces should be equal to the committee member count");
        // assertEq(aggregatedKey, committeeKey, "aggregatedKey should be equal to the committee key");

        SignatureData[] memory signatures = signatureManager.getPartialSignatures(hashToSign);
        assertEq(
            signatures.length, committeeMemberCount, "signatures length should be equal to the committee member count"
        );

        for (uint256 i = 0; i < signatures.length; i++) {
            assertEq(signatures[i].signature, bytes32(0), "signatures[i].signature should be empty");
            assertEq(signatures[i].nonce.length, 0, "signatures[i].nonce should be empty");
        }
    }

    function test_initSignatures_Revert_InvalidHashToSign() external {
        // Arrange
        bytes32 hashToSign = 0x0000000000000000000000000000000000000000000000000000000000000000;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.InvalidHashToSign.selector, hashToSign));

        // Act
        vm.prank(address(pm));
        signatureManager.initSignatures(hashToSign, COMMITTEE_ID_STREAM_1_PACKET_0);
    }

    function test_initSignatures_Revert_SignaturesAlreadyInitialized() external {
        // Arrange
        uint256 committeeId = COMMITTEE_ID_STREAM_1_PACKET_0;
        bytes32 hashToSign = 0x1000000000000000000000000000000000000000000000000000000000000001;

        // First time initializing the signatures
        vm.prank(address(pm));
        signatureManager.initSignatures(hashToSign, committeeId);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.SignaturesAlreadyInitialized.selector, hashToSign));

        // Act second time initializing the signatures
        vm.prank(address(pm));
        signatureManager.initSignatures(hashToSign, committeeId);
    }

    function test_initSignatures_Revert_CommitteeNotFound() external {
        // Arrange
        uint256 committeeId = 1;
        bytes32 hashToSign = 0x1000000000000000000000000000000000000000000000000000000000000001;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeNotFound.selector, committeeId));

        // Act
        vm.prank(address(pm));
        signatureManager.initSignatures(hashToSign, committeeId);
    }

    function test_initSignatures_Revert_Unauthorized() external {
        // Arrange
        bytes32 hashToSign = 0x1000000000000000000000000000000000000000000000000000000000000001;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.UnauthorizedAccount.selector, address(this)));

        // Act
        signatureManager.initSignatures(hashToSign, COMMITTEE_ID_STREAM_1_PACKET_0);
    }

    function setup_initSignatures() internal returns (bytes32) {
        bytes32 hashToSign = 0x1200000000000000000000000000000000000000000000000000000000000001;

        // Act
        vm.prank(address(pm));
        signatureManager.initSignatures(hashToSign, COMMITTEE_ID_STREAM_1_PACKET_0);

        return hashToSign;
    }

    function setup_addAllNonces(bytes32 hashToSign) internal {
        setup_addMemberNonce_MultipleMembers(hashToSign, 0, registry.minCommitteeMembers());
    }

    function setup_initOperatorTakeTxHashes() internal returns (bytes32) {
        // initOperatorTakeTxHashes is executed when a new pegin request is created
        setup_multipleRequestAndAcceptPeginFlows(1, setupStreamId);
        // Real acceptPeginTxHash value for first request
        bytes32 acceptPeginTxHash = ACCEPT_PEGIN_TX_HASH;
        return acceptPeginTxHash;
    }

    function setup_addOperatorTake_MultipleMembers(
        bytes32 acceptPeginTxHash,
        uint256 operatorIndexStart,
        uint256 operatorCount
    ) internal {
        uint256 operatorIndexEnd = operatorIndexStart + operatorCount;
        for (uint256 i = operatorIndexStart; i < operatorIndexEnd; i++) {
            address memberAddress = vm.addr(i + 1);
            bytes32 txHash = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
            vm.prank(memberAddress);
            signatureManager.addOperatorTakeTxHash(acceptPeginTxHash, txHash);
        }
    }

    function test_getOperatorTakeData_Revert_AcceptPeginTxHashNotFound() external {
        // Arrange
        bytes32 acceptPeginTxHash = ACCEPT_PEGIN_TX_HASH;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.AcceptPeginTxHashNotFound.selector, acceptPeginTxHash));

        // Act
        signatureManager.getOperatorTakeData(acceptPeginTxHash);
    }

    function countEmptyOperatorTakeTxHashes(OperatorTakeData[] memory operatorTakeData)
        internal
        pure
        returns (uint256)
    {
        uint256 emptyCount = 0;
        for (uint256 i = 0; i < operatorTakeData.length; i++) {
            if (operatorTakeData[i].txHash == bytes32(0)) {
                emptyCount++;
            }
        }
        return emptyCount;
    }

    function test_initOperatorTakeTxHashes_Success() external {
        // Arrange
        uint256 operatorsCount = registry.minCommitteeMembers() / 2;
        bytes32 acceptPeginTxHash = ACCEPT_PEGIN_TX_HASH;

        // Act
        vm.prank(address(pm));
        signatureManager.initOperatorTakeTxHashes(acceptPeginTxHash, COMMITTEE_ID_STREAM_1_PACKET_0);

        // Assert
        OperatorTakeData[] memory operatorTakeData = signatureManager.getOperatorTakeData(acceptPeginTxHash);
        uint256 missingHashes = countEmptyOperatorTakeTxHashes(operatorTakeData);
        assertEq(missingHashes, operatorsCount, "missingHashes should be equal to operatorsCount");

        uint256 committeeId = signatureManager.getCommitteeIdByAcceptPeginTxHash(acceptPeginTxHash);
        assertEq(committeeId, COMMITTEE_ID_STREAM_1_PACKET_0, "committeeId should match");
    }

    function test_addOperatorTakeTxHash_Success() external {
        // Arrange
        bytes32 acceptPeginTxHash = setup_initOperatorTakeTxHashes();
        uint256 operatorIndex = registry.minCommitteeMembers() / 2;
        address memberAddress = vm.addr(operatorIndex + 1);
        bytes32 operatorTakeTxHash = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Assert
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.OperatorTakeTxHashAdded(acceptPeginTxHash, memberAddress, operatorTakeTxHash);

        vm.prank(memberAddress);
        signatureManager.addOperatorTakeTxHash(acceptPeginTxHash, operatorTakeTxHash);
    }

    function test_addOperatorTakeTxHash_Success_AllOperatorTakeTxHashesAdded() external {
        // Arrange
        bytes32 acceptPeginTxHash = setup_initOperatorTakeTxHashes();
        uint256 operatorCount = registry.minCommitteeMembers() / 2;
        uint256 operatorIndexStart = registry.minCommitteeMembers() / 2;
        setup_addOperatorTake_MultipleMembers(acceptPeginTxHash, operatorIndexStart, operatorCount - 1);

        uint256 lastOperatorIndex = registry.minCommitteeMembers() - 1;
        address lastMemberAddress = vm.addr(lastOperatorIndex + 1);
        bytes32 lastMemberTxHash = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Assert
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.OperatorTakeTxHashAdded(acceptPeginTxHash, lastMemberAddress, lastMemberTxHash);

        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.AllOperatorTakeTxHashesAdded(acceptPeginTxHash);

        // Act
        vm.prank(lastMemberAddress);
        signatureManager.addOperatorTakeTxHash(acceptPeginTxHash, lastMemberTxHash);
    }

    function test_addOperatorTakeTxHash_Revert_AcceptPeginTxHashNotFound() external {
        // Arrange
        uint256 operatorIndex = registry.minCommitteeMembers() / 2;
        address memberAddress = vm.addr(operatorIndex + 1);
        bytes32 operatorTakeTxHash = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        // It wont exists because there was no pegin request yet
        bytes32 acceptPeginTxHash = ACCEPT_PEGIN_TX_HASH;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.AcceptPeginTxHashNotFound.selector, acceptPeginTxHash));

        vm.prank(memberAddress);
        signatureManager.addOperatorTakeTxHash(acceptPeginTxHash, operatorTakeTxHash);
    }

    function test_addOperatorTakeTxHash_Revert_MemberNotFoundInCommittee() external {
        // Arrange
        bytes32 acceptPeginTxHash = setup_initOperatorTakeTxHashes();
        bytes32 operatorTakeTxHash = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Register a new member that it's not in the committee
        uint256 notMemberIndex = registry.minCommitteeMembers();
        address notMemberAddress = vm.addr(notMemberIndex + 1);
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(notMemberIndex + 1);
        setup_applyToStream(StreamDenomination(setupStreamId), notMemberAddress, pubKeysRegistration, Role.OPERATOR);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberNotFoundInCommittee.selector, COMMITTEE_ID_STREAM_1_PACKET_0, notMemberAddress
            )
        );

        // Act
        vm.prank(notMemberAddress);
        signatureManager.addOperatorTakeTxHash(acceptPeginTxHash, operatorTakeTxHash);
    }

    function test_addOperatorTakeTxHash_Revert_MemberIsNotOperator() external {
        // Arrange
        bytes32 acceptPeginTxHash = setup_initOperatorTakeTxHashes();
        uint256 notOperatorIndex = 0;
        address notOperatorAddress = vm.addr(notOperatorIndex + 1);
        bytes32 operatorTakeTxHash = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberIsNotOperator.selector, COMMITTEE_ID_STREAM_1_PACKET_0, notOperatorAddress
            )
        );

        // Act
        vm.prank(notOperatorAddress);
        signatureManager.addOperatorTakeTxHash(acceptPeginTxHash, operatorTakeTxHash);
    }

    function test_addOperatorTakeTxHash_Revert_MemberHasAlreadyAddedoperatorTakeTxHash() external {
        // Arrange
        bytes32 acceptPeginTxHash = setup_initOperatorTakeTxHashes();
        uint256 operatorIndex = registry.minCommitteeMembers() / 2;
        address memberAddress = vm.addr(operatorIndex + 1);
        bytes32 operatorTakeTxHash = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        vm.prank(memberAddress);
        signatureManager.addOperatorTakeTxHash(acceptPeginTxHash, operatorTakeTxHash);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberAlreadyAddedOperatorTakeTxHash.selector,
                acceptPeginTxHash,
                memberAddress,
                operatorTakeTxHash
            )
        );

        // Act
        vm.prank(memberAddress);
        signatureManager.addOperatorTakeTxHash(acceptPeginTxHash, operatorTakeTxHash);
    }

    function test_addOperatorTakeTxHash_Revert_AllHashesAlreadyPresent() external {
        // Arrange
        bytes32 acceptPeginTxHash = setup_initOperatorTakeTxHashes();
        uint256 operatorCount = registry.minCommitteeMembers() / 2;
        uint256 operatorIndexStart = registry.minCommitteeMembers() / 2;
        uint256 lastOperatorIndex = registry.minCommitteeMembers() - 1;
        address lastMemberAddress = vm.addr(lastOperatorIndex + 1);
        bytes32 lastMemberTxHash = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Complet all operator OperatorTake tx hashes here
        setup_addOperatorTake_MultipleMembers(acceptPeginTxHash, operatorIndexStart, operatorCount);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ISignatureManager.AllOperatorTakeTxHashesAlreadyPresent.selector, acceptPeginTxHash)
        );

        // Act
        vm.prank(lastMemberAddress);
        signatureManager.addOperatorTakeTxHash(acceptPeginTxHash, lastMemberTxHash);
    }

    function test_checkAllOperatorTakesHashesReady_Revert_AcceptPeginTxHashNotFound() external {
        // Arrange
        bytes32 acceptPeginTxHash = ACCEPT_PEGIN_TX_HASH;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.AcceptPeginTxHashNotFound.selector, acceptPeginTxHash));

        // Act
        signatureManager.checkAllOperatorTakesHashesReady(acceptPeginTxHash);
    }

    function test_checkAllOperatorTakesHashesReady_False() external {
        // Arrange
        bytes32 acceptPeginTxHash = setup_initOperatorTakeTxHashes();

        // Assert
        bool allOperatorTakeHashesReady = signatureManager.checkAllOperatorTakesHashesReady(acceptPeginTxHash);
        assertEq(allOperatorTakeHashesReady, false, "Not all operator take hashes should be ready at this point");
    }

    function test_checkAllOperatorTakesHashesReady_True() external {
        // Arrange
        bytes32 acceptPeginTxHash = setup_initOperatorTakeTxHashes();
        uint256 operatorCount = registry.minCommitteeMembers() / 2;
        uint256 operatorIndexStart = registry.minCommitteeMembers() / 2;
        uint256 lastOperator = operatorIndexStart + operatorCount;
        bool allOperatorTakeHashesReady;

        for (uint256 i = operatorIndexStart; i < lastOperator; i++) {
            address memberAddress = vm.addr(i + 1);
            bytes32 txHash = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

            // Act
            allOperatorTakeHashesReady = signatureManager.checkAllOperatorTakesHashesReady(acceptPeginTxHash);

            // Assert
            assertEq(allOperatorTakeHashesReady, false, "Not all operator take hashes should be ready at this point");

            // Arrange (Add new operator take tx hash)
            vm.prank(memberAddress);
            signatureManager.addOperatorTakeTxHash(acceptPeginTxHash, txHash);
        }

        // Act
        allOperatorTakeHashesReady = signatureManager.checkAllOperatorTakesHashesReady(acceptPeginTxHash);

        // Assert
        assertEq(allOperatorTakeHashesReady, true, "All operator take hashes should be ready at this point");
    }
}
