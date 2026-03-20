// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {
    Committee,
    ICommitteeRegistry,
    StreamDenomination,
    Role,
    CommitteeMember
} from "src/interfaces/ICommitteeRegistry.sol";
import {MemberRegistrationKeys} from "src/interfaces/IMemberRegistry.sol";
import {IAccessManager} from "src/interfaces/IAccessManager.sol";
import {SignatureData, ISignatureManager, OperatorTakeData} from "src/interfaces/ISignatureManager.sol";
import {Constants} from "src/libraries/Constants.sol";

contract SignatureManagerTest is Test, HelperContract {
    uint128 internal setupCommitteeId;
    Committee internal setupExpectedCommittee;
    bytes32 constant ACCEPT_PEGIN_TXID = hex"14fdaad7499abf1ef94b3705749fad1d3979cce2dc636e978b83e756bd6ad23a";

    function setUp() external {
        runTestDeployScript();
        (Committee memory expectedCommittee, uint128 committeeId) = setup_completeCommittee();

        setupExpectedCommittee.takeAggregatedKey = expectedCommittee.takeAggregatedKey;
        setupExpectedCommittee.leaderAddress = expectedCommittee.leaderAddress;
        setupExpectedCommittee.streamId = expectedCommittee.streamId;
        for (uint64 i = 0; i < expectedCommittee.members.length; i++) {
            setupExpectedCommittee.members.push(expectedCommittee.members[i]);
        }

        setupCommitteeId = committeeId;
    }

    // we only check the revert case since the success cases are being checked in the _addMemberSignaturePegout tests
    function test_checkAllSignaturesReady_Revert_PegoutRequestNotFound() external {
        // Arrange
        bytes32 txid = 0x0000000000000000000000000000000000000000000000000000000000000001;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.TxidToSignNotFound.selector, txid));

        // Act
        signatureManager.checkAllSignaturesReady(txid);
    }

    function test_addMemberNonce_Success() external {
        // Arrange
        bytes32 txid = setup_initSignatures();
        // The nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        address committeeMember0adr = vm.addr(1);

        // Assert
        // We emit the event we expect to see.
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.NonceAdded(txid, committeeMember0adr, nonce);

        // Act
        vm.prank(committeeMember0adr);
        bool allNoncesReady = signatureManager.addMemberNonce(txid, nonce);

        // Assert
        assertEq(allNoncesReady, false, "Not all nonces should be ready at this point");
    }

    function test_addMemberNonce_Success_AllNoncesReady() external {
        // Arrange
        bytes32 txid = setup_initSignatures();
        // The nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        setup_addMemberNonce_MultipleMembers(txid, 0, registry.committeeMemberCount() - 1);
        uint256 lastMemberIndex = registry.committeeMemberCount() - 1;
        address lastMemberAddress = vm.addr(lastMemberIndex + 1);

        // Assert
        // We emit the event we expect to see.
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.NonceAdded(txid, lastMemberAddress, nonce);

        // We emit the event we expect to see.
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.AllNoncesReady(txid);

        // Act
        vm.prank(lastMemberAddress);
        bool allNoncesReady = signatureManager.addMemberNonce(txid, nonce);

        // Assert
        assertEq(allNoncesReady, true, "Not all nonces should be ready at this point");
    }

    function test_addMemberSignature_Success() external {
        // Arrange
        // Init signatures and add all nonces
        bytes32 txid = setup_initSignatures();
        setup_addAllNonces(txid);
        // The signature an nonce values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        uint256 memberIndex = 0;
        address committeeMember0adr = vm.addr(memberIndex + 1);

        // We emit the event we expect to see.
        // Assert
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.SignatureAdded(txid, committeeMember0adr, signature);

        // Act
        vm.prank(committeeMember0adr);
        bool allSignaturesReady = signatureManager.addMemberSignature(txid, signature);

        // Assert
        assertEq(allSignaturesReady, false, "Not all signatures should be ready at this point");
        (SignatureData[] memory signatures, uint8 missingNonces, uint128 committeeId) =
            signatureManager.getPartialSignatures(txid);
        // Check the missing nonces
        assertEq(missingNonces, 0, "missingNonces should be equal to 1");
        // Check the committee id
        assertEq(
            committeeId,
            COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            "committeeId should be equal to the committee id that was created initially"
        );
        // Check the signatures length
        assertEq(
            signatures.length,
            registry.committeeMemberCount(),
            "signatures length should be equal to registry.committeeMemberCount()"
        );
        // Check the signatures are empty for the members other than the one who signed
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
        bytes32 txid = setup_initSignatures();
        setup_addAllNonces(txid);
        // The signature an nonce values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        uint256 memberCount = registry.committeeMemberCount();
        setup_addMemberSignature_MultipleMembers(txid, 0, memberCount - 1);
        // Pub key and address are generated based on the member index + 1
        uint256 lastMemberIndex = registry.committeeMemberCount() - 1;
        address lastMemberAddress = vm.addr(lastMemberIndex + 1);

        // Assert
        // We emit the event we expect to see.
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.SignatureAdded(txid, lastMemberAddress, signature);

        // We emit the event we expect to see.
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.AllSignaturesReady(txid);

        // Act
        vm.prank(lastMemberAddress);
        bool allSignaturesReady = signatureManager.addMemberSignature(txid, signature);

        // Assert
        assertEq(allSignaturesReady, true, "Not all signatures should be ready at this point");
        (SignatureData[] memory signatures, uint8 missingNonces, uint128 committeeId) =
            signatureManager.getPartialSignatures(txid);
        // Check the missing nonces
        assertEq(missingNonces, 0, "missingNonces should be equal to 0");
        // Check the committee id
        assertEq(
            committeeId,
            COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            "committeeId should be equal to the committee id that was created initially"
        );
        // Check the signatures length
        assertEq(
            signatures.length,
            registry.committeeMemberCount(),
            "signatures length should be equal to registry.committeeMemberCount()"
        );
        // Check the signatures are not empty
        CommitteeMember[] memory members = registry.getCommitteeMembers(committeeId);
        for (uint256 i = 0; i < members.length; i++) {
            assertNotEq(signatures[i].signature, bytes32(0), "signatures[i].signature should not be empty");
        }
    }

    function test_addMemberNonce_Revert_TxidToSignNotFound() external {
        // Arrange
        bytes32 txid = 0x0000000000000000000000000000000000000000000000000000000000000001;

        // The signature an nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.TxidToSignNotFound.selector, txid));

        // Act
        vm.prank(vm.addr(1));
        signatureManager.addMemberNonce(txid, nonce);
    }

    function test_addMemberSignature_Revert_TxidToSignNotFound() external {
        // Arrange
        bytes32 txid = 0x0000000000000000000000000000000000000000000000000000000000000001;
        address memberAddress = vm.addr(registry.committeeMemberCount() + 1);
        // The signature an nonce values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.TxidToSignNotFound.selector, txid));

        // Act
        vm.prank(memberAddress);
        signatureManager.addMemberSignature(txid, signature);
    }

    function test_addMemberNonce_Revert_MemberHasAlreadySigned() external {
        // Arrange
        // Init signatures
        bytes32 txid = setup_initSignatures();
        // The nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        address committeeMember0adr = vm.addr(1);

        // First time adding the nonce
        vm.prank(committeeMember0adr);
        signatureManager.addMemberNonce(txid, nonce);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ISignatureManager.MemberAlreadyAddedNonce.selector, committeeMember0adr, nonce)
        );

        // Act add nonce a second time with the same committee member
        vm.prank(committeeMember0adr);
        signatureManager.addMemberNonce(txid, nonce);
    }

    function test_addMemberSignature_Revert_MemberHasAlreadySigned() external {
        // Init signatures and add all nonces
        bytes32 txid = setup_initSignatures();
        setup_addAllNonces(txid);
        // Arrange
        // The signature values are dummy values
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        address committeeMember0adr = vm.addr(1);

        // Sign the first time
        vm.prank(committeeMember0adr);
        signatureManager.addMemberSignature(txid, signature);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ISignatureManager.MemberHasAlreadySigned.selector, committeeMember0adr, txid)
        );

        // Act sign a second time with the same committee member
        vm.prank(committeeMember0adr);
        signatureManager.addMemberSignature(txid, signature);
    }

    function test_addMemberNonce_Revert_MemberNotFoundInCommittee() external {
        // Arrange
        bytes32 txid = setup_initSignatures();
        address nonCommitteeMember = vm.addr(registry.committeeMemberCount() + 1);
        MemberRegistrationKeys memory nonCommitteeMemberPubKeysRegistration =
            generateRegistrationPublicKeys(uint256(uint160(nonCommitteeMember)));
        setup_applyToStream(
            StreamDenomination._0_01BTC, nonCommitteeMember, nonCommitteeMemberPubKeysRegistration, Role.OPERATOR
        );
        // The nonce values are dummy values
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberNotFoundInCommittee.selector,
                COMMITTEE_ID_STREAM_1_COMMITTEE_1,
                nonCommitteeMember
            )
        );

        // Act
        vm.prank(nonCommitteeMember);
        signatureManager.addMemberNonce(txid, nonce);
    }

    function test_addMemberSignature_Revert_MemberNotFoundInCommittee() external {
        // Arrange
        // Init signatures and add all nonces
        bytes32 txid = setup_initSignatures();
        setup_addAllNonces(txid);

        address nonCommitteeMember = vm.addr(registry.committeeMemberCount() + 1);
        MemberRegistrationKeys memory nonCommitteeMemberPubKeysRegistration =
            generateRegistrationPublicKeys(uint256(uint160(nonCommitteeMember)));
        setup_applyToStream(
            StreamDenomination._0_01BTC, nonCommitteeMember, nonCommitteeMemberPubKeysRegistration, Role.OPERATOR
        );
        bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberNotFoundInCommittee.selector,
                COMMITTEE_ID_STREAM_1_COMMITTEE_1,
                nonCommitteeMember
            )
        );

        // Act
        vm.prank(nonCommitteeMember);
        signatureManager.addMemberSignature(txid, signature);
    }

    function test_addMemberSignature_Revert_InvalidNonceLength() external {
        bytes32 txid = setup_initSignatures();

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
        signatureManager.addMemberNonce(txid, nonce);
    }

    function test_initSignatures_Success() external {
        // Arrange
        uint8 committeeMemberCount = uint8(registry.committeeMemberCount());
        bytes32 txid = 0x1000000000000000000000000000000000000000000000000000000000000001;

        // Act
        vm.prank(address(pegoutManager));
        signatureManager.initSignatures(txid, COMMITTEE_ID_STREAM_1_COMMITTEE_1);

        // Assert
        (SignatureData[] memory signatures, uint8 missingNonces, uint128 committeeId) =
            signatureManager.getPartialSignatures(txid);
        // Check the missing nonces
        assertEq(missingNonces, committeeMemberCount, "missingNonces should be equal to the committee member count");
        // Check the committee id
        assertEq(
            committeeId,
            COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            "committeeId should be equal to the committee id that was created initially"
        );
        // Check the signatures length
        assertEq(
            signatures.length, committeeMemberCount, "signatures length should be equal to the committee member count"
        );
        // Check the signatures and nonces are empty
        for (uint256 i = 0; i < signatures.length; i++) {
            assertEq(signatures[i].signature, bytes32(0), "signatures[i].signature should be empty");
            assertEq(signatures[i].nonce.length, 0, "signatures[i].nonce should be empty");
        }
    }

    function test_initSignatures_Revert_InvalidTxidToSign() external {
        // Arrange
        bytes32 txid = 0x0000000000000000000000000000000000000000000000000000000000000000;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.InvalidTxidToSign.selector, txid));

        // Act
        vm.prank(address(pegoutManager));
        signatureManager.initSignatures(txid, COMMITTEE_ID_STREAM_1_COMMITTEE_1);
    }

    function test_initSignatures_Revert_SignaturesAlreadyInitialized() external {
        // Arrange
        uint128 committeeId = COMMITTEE_ID_STREAM_1_COMMITTEE_1;
        bytes32 txid = 0x1000000000000000000000000000000000000000000000000000000000000001;

        // First time initializing the signatures
        vm.prank(address(pegoutManager));
        signatureManager.initSignatures(txid, committeeId);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.SignaturesAlreadyInitialized.selector, txid));

        // Act second time initializing the signatures
        vm.prank(address(pegoutManager));
        signatureManager.initSignatures(txid, committeeId);
    }

    function test_initSignatures_Revert_CommitteeNotFound() external {
        // Arrange
        uint128 committeeId = 1;
        bytes32 txid = 0x1000000000000000000000000000000000000000000000000000000000000001;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ICommitteeRegistry.CommitteeNotFound.selector, committeeId));

        // Act
        vm.prank(address(pegoutManager));
        signatureManager.initSignatures(txid, committeeId);
    }

    function test_initSignatures_Revert_Unauthorized() external {
        // Arrange
        bytes32 txid = 0x1000000000000000000000000000000000000000000000000000000000000001;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.UnauthorizedToInitSignatures.selector, address(this)));

        // Act
        signatureManager.initSignatures(txid, COMMITTEE_ID_STREAM_1_COMMITTEE_1);
    }

    function setup_initSignatures() internal returns (bytes32) {
        bytes32 txid = 0x1200000000000000000000000000000000000000000000000000000000000001;

        // Act
        vm.prank(address(pegoutManager));
        signatureManager.initSignatures(txid, COMMITTEE_ID_STREAM_1_COMMITTEE_1);

        return txid;
    }

    function setup_addAllNonces(bytes32 txid) internal {
        setup_addMemberNonce_MultipleMembers(txid, 0, registry.committeeMemberCount());
    }

    function setup_initOperatorTakeTxids() internal returns (bytes32) {
        // initOperatorTakeTxids is executed when a new request pegin is created
        setup_multipleRequestAndAcceptPeginFlows(1);
        // Real acceptPeginTxid value for first request
        bytes32 acceptPeginTxid = ACCEPT_PEGIN_TXID;
        return acceptPeginTxid;
    }

    function setup_addOperatorTake_MultipleMembers(
        bytes32 acceptPeginTxid,
        uint256 operatorIndexStart,
        uint256 operatorCount
    ) internal {
        uint256 operatorIndexEnd = operatorIndexStart + operatorCount;
        for (uint256 i = operatorIndexStart; i < operatorIndexEnd; i++) {
            address memberAddress = vm.addr(i + 1);
            bytes32 takeTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
            bytes32 wonTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a1";
            vm.prank(memberAddress);
            signatureManager.addOperatorTakeTxids(acceptPeginTxid, takeTxid, wonTxid);
        }
    }

    function test_getOperatorTakeData_Revert_AcceptPeginTxidNotFound() external {
        // Arrange
        bytes32 acceptPeginTxid = ACCEPT_PEGIN_TXID;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.AcceptPeginTxidNotFound.selector, acceptPeginTxid));

        // Act
        signatureManager.getOperatorTakeData(acceptPeginTxid);
    }

    function countEmptyOperatorTakeTxids(OperatorTakeData[] memory operatorTakeData) internal pure returns (uint256) {
        uint256 emptyCount = 0;
        for (uint256 i = 0; i < operatorTakeData.length; i++) {
            if (operatorTakeData[i].takeTxid == bytes32(0) || operatorTakeData[i].wonTxid == bytes32(0)) {
                emptyCount++;
            }
        }
        return emptyCount;
    }

    function test_initOperatorTakeTxids_Success() external {
        // Arrange
        uint256 operatorsCount = registry.committeeMemberCount() / 2;
        bytes32 acceptPeginTxid = ACCEPT_PEGIN_TXID;

        // Act
        vm.prank(address(peginManager));
        signatureManager.initOperatorTakeTxids(acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1);

        // Assert
        OperatorTakeData[] memory operatorTakeData = signatureManager.getOperatorTakeData(acceptPeginTxid);
        uint256 missingHashes = countEmptyOperatorTakeTxids(operatorTakeData);
        assertEq(missingHashes, operatorsCount, "missingHashes should be equal to operatorsCount");

        uint128 committeeId = signatureManager.getCommitteeIdByAcceptPeginTxid(acceptPeginTxid);
        assertEq(committeeId, COMMITTEE_ID_STREAM_1_COMMITTEE_1, "committeeId should match");
    }

    function test_addOperatorTakeTxids_Success() external {
        // Arrange
        bytes32 acceptPeginTxid = setup_initOperatorTakeTxids();
        uint256 operatorIndex = registry.committeeMemberCount() / 2;
        address memberAddress = vm.addr(operatorIndex + 1);
        bytes32 operatorTakeTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        bytes32 operatorWonTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Assert
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.OperatorTakeTxidsAdded(acceptPeginTxid, memberAddress, operatorTakeTxid, operatorWonTxid);

        vm.prank(memberAddress);
        signatureManager.addOperatorTakeTxids(acceptPeginTxid, operatorTakeTxid, operatorWonTxid);
    }

    function test_addOperatorTakeTxids_Revert_InvalidTxid_OperatorTake() external {
        // Arrange
        bytes32 acceptPeginTxid = setup_initOperatorTakeTxids();
        uint256 operatorIndex = registry.committeeMemberCount() / 2;
        address memberAddress = vm.addr(operatorIndex + 1);
        bytes32 operatorTakeTxid = hex"00";
        bytes32 operatorWonTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.InvalidHash.selector, operatorTakeTxid));

        vm.prank(memberAddress);
        signatureManager.addOperatorTakeTxids(acceptPeginTxid, operatorTakeTxid, operatorWonTxid);
    }

    function test_addOperatorTakeTxids_Revert_InvalidTxid_OperatorWon() external {
        // Arrange
        bytes32 acceptPeginTxid = setup_initOperatorTakeTxids();
        uint256 operatorIndex = registry.committeeMemberCount() / 2;
        address memberAddress = vm.addr(operatorIndex + 1);
        bytes32 operatorWonTxid = hex"00";
        bytes32 operatorTakeTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.InvalidHash.selector, operatorWonTxid));

        vm.prank(memberAddress);
        signatureManager.addOperatorTakeTxids(acceptPeginTxid, operatorTakeTxid, operatorWonTxid);
    }

    function test_addOperatorTakeTxids_Success_AllOperatorTakeTxidsAdded() external {
        // Arrange
        bytes32 acceptPeginTxid = setup_initOperatorTakeTxids();
        uint256 operatorCount = registry.committeeMemberCount() / 2;
        uint256 operatorIndexStart = registry.committeeMemberCount() / 2;
        setup_addOperatorTake_MultipleMembers(acceptPeginTxid, operatorIndexStart, operatorCount - 1);

        uint256 lastOperatorIndex = registry.committeeMemberCount() - 1;
        address lastMemberAddress = vm.addr(lastOperatorIndex + 1);
        bytes32 takeTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        bytes32 wonTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a1";

        // Assert
        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.OperatorTakeTxidsAdded(acceptPeginTxid, lastMemberAddress, takeTxid, wonTxid);

        vm.expectEmit(address(signatureManager));
        emit ISignatureManager.AllOperatorTakeTxidsAdded(acceptPeginTxid);

        // Act
        vm.prank(lastMemberAddress);
        signatureManager.addOperatorTakeTxids(acceptPeginTxid, takeTxid, wonTxid);

        // Assert
        OperatorTakeData[] memory operatorTakeData = signatureManager.getOperatorTakeData(acceptPeginTxid);
        for (uint256 i = 0; i < operatorTakeData.length; i++) {
            assertEq(operatorTakeData[i].takeTxid, takeTxid, "operatorTakeData[i].takeTxid should equal to takeTxid");
            assertEq(operatorTakeData[i].wonTxid, wonTxid, "operatorTakeData[i].wonTxid should equal to wonTxid");
        }
    }

    function test_addOperatorTakeTxids_Revert_AcceptPeginTxidNotFound() external {
        // Arrange
        uint256 operatorIndex = registry.committeeMemberCount() / 2;
        address memberAddress = vm.addr(operatorIndex + 1);
        bytes32 operatorTakeTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        bytes32 operatorWonTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        // It wont exists because there was no request pegin yet
        bytes32 acceptPeginTxid = ACCEPT_PEGIN_TXID;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.AcceptPeginTxidNotFound.selector, acceptPeginTxid));

        vm.prank(memberAddress);
        signatureManager.addOperatorTakeTxids(acceptPeginTxid, operatorTakeTxid, operatorWonTxid);
    }

    function test_addOperatorTakeTxids_Revert_MemberNotFoundInCommittee() external {
        // Arrange
        bytes32 acceptPeginTxid = setup_initOperatorTakeTxids();
        bytes32 operatorTakeTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        bytes32 operatorWonTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Register a new member that it's not in the committee
        uint256 notMemberIndex = registry.committeeMemberCount();
        address notMemberAddress = vm.addr(notMemberIndex + 1);
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(notMemberIndex + 1);
        setup_applyToStream(
            StreamDenomination(setupExpectedCommittee.streamId), notMemberAddress, memberRegistrationKeys, Role.OPERATOR
        );

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberNotFoundInCommittee.selector,
                COMMITTEE_ID_STREAM_1_COMMITTEE_1,
                notMemberAddress
            )
        );

        // Act
        vm.prank(notMemberAddress);
        signatureManager.addOperatorTakeTxids(acceptPeginTxid, operatorTakeTxid, operatorWonTxid);
    }

    function test_addOperatorTakeTxids_Revert_MemberIsNotOperator() external {
        // Arrange
        bytes32 acceptPeginTxid = setup_initOperatorTakeTxids();
        uint256 notOperatorIndex = 0;
        address notOperatorAddress = vm.addr(notOperatorIndex + 1);
        bytes32 operatorTakeTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        bytes32 operatorWonTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberIsNotOperator.selector, COMMITTEE_ID_STREAM_1_COMMITTEE_1, notOperatorAddress
            )
        );

        // Act
        vm.prank(notOperatorAddress);
        signatureManager.addOperatorTakeTxids(acceptPeginTxid, operatorTakeTxid, operatorWonTxid);
    }

    function test_addOperatorTakeTxids_Revert_MemberHasAlreadyAddedoperatorTakeTxid() external {
        // Arrange
        bytes32 acceptPeginTxid = setup_initOperatorTakeTxids();
        uint256 operatorIndex = registry.committeeMemberCount() / 2;
        address memberAddress = vm.addr(operatorIndex + 1);
        bytes32 operatorTakeTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        bytes32 operatorWonTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        vm.prank(memberAddress);
        signatureManager.addOperatorTakeTxids(acceptPeginTxid, operatorTakeTxid, operatorWonTxid);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ISignatureManager.MemberAlreadyAddedOperatorTakeTxids.selector,
                acceptPeginTxid,
                memberAddress,
                operatorTakeTxid,
                operatorWonTxid
            )
        );

        // Act
        vm.prank(memberAddress);
        signatureManager.addOperatorTakeTxids(acceptPeginTxid, operatorTakeTxid, operatorWonTxid);
    }

    function test_addOperatorTakeTxids_Revert_AllHashesAlreadyPresent() external {
        // Arrange
        bytes32 acceptPeginTxid = setup_initOperatorTakeTxids();
        uint256 operatorCount = registry.committeeMemberCount() / 2;
        uint256 operatorIndexStart = registry.committeeMemberCount() / 2;
        uint256 lastOperatorIndex = registry.committeeMemberCount() - 1;
        address lastMemberAddress = vm.addr(lastOperatorIndex + 1);
        bytes32 lastMemberTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
        bytes32 lastMemberWonTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

        // Complet all operator OperatorTake tx id's here
        setup_addOperatorTake_MultipleMembers(acceptPeginTxid, operatorIndexStart, operatorCount);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(ISignatureManager.AllOperatorTakeTxidsAlreadyPresent.selector, acceptPeginTxid)
        );

        // Act
        vm.prank(lastMemberAddress);
        signatureManager.addOperatorTakeTxids(acceptPeginTxid, lastMemberTxid, lastMemberWonTxid);
    }

    function test_checkAllOperatorTakesHashesReady_Revert_AcceptPeginTxidNotFound() external {
        // Arrange
        bytes32 acceptPeginTxid = ACCEPT_PEGIN_TXID;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.AcceptPeginTxidNotFound.selector, acceptPeginTxid));

        // Act
        signatureManager.checkAllOperatorTakesHashesReady(acceptPeginTxid);
    }

    function test_checkAllOperatorTakesHashesReady_False() external {
        // Arrange
        bytes32 acceptPeginTxid = setup_initOperatorTakeTxids();

        // Assert
        bool allOperatorTakeHashesReady = signatureManager.checkAllOperatorTakesHashesReady(acceptPeginTxid);
        assertEq(allOperatorTakeHashesReady, false, "Not all operator take hashes should be ready at this point");
    }

    function test_checkAllOperatorTakesHashesReady_True() external {
        // Arrange
        bytes32 acceptPeginTxid = setup_initOperatorTakeTxids();
        uint256 operatorCount = registry.committeeMemberCount() / 2;
        uint256 operatorIndexStart = registry.committeeMemberCount() / 2;
        uint256 lastOperator = operatorIndexStart + operatorCount;
        bool allOperatorTakeHashesReady;

        for (uint256 i = operatorIndexStart; i < lastOperator; i++) {
            address memberAddress = vm.addr(i + 1);
            bytes32 txid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
            bytes32 wonTxid = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";

            // Act
            allOperatorTakeHashesReady = signatureManager.checkAllOperatorTakesHashesReady(acceptPeginTxid);

            // Assert
            assertEq(allOperatorTakeHashesReady, false, "Not all operator take hashes should be ready at this point");

            // Arrange (Add new operator take tx id)
            vm.prank(memberAddress);
            signatureManager.addOperatorTakeTxids(acceptPeginTxid, txid, wonTxid);
        }

        // Act
        allOperatorTakeHashesReady = signatureManager.checkAllOperatorTakesHashesReady(acceptPeginTxid);

        // Assert
        assertEq(allOperatorTakeHashesReady, true, "All operator take hashes should be ready at this point");
    }
}
