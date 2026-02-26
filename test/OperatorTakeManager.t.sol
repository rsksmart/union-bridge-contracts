// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {BtcTxSPVProof, StreamPosition, PegStatus} from "src/interfaces/IPegCommonTypes.sol";
import {OperatorTakeInfo} from "src/interfaces/IOperatorTakeManager.sol";
import {IPegoutManager} from "src/interfaces/IPegoutManager.sol";
import {SlotState, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {Committee} from "src/interfaces/ICommitteeRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessManager} from "src/interfaces/IAccessManager.sol";
import {IOperatorTakeManager, TakeTimeout} from "src/interfaces/IOperatorTakeManager.sol";
import {BtcTxIn, BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {Constants} from "src/libraries/Constants.sol";
import {IRbtcBridge} from "src/interfaces/IRbtcBridge.sol";
import {IPegBase} from "src/interfaces/IPegBase.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {BtcScriptParser} from "src/libraries/BtcScriptParser.sol";

contract OperatorTakeManagerTest is Test, HelperContract {
    function setUp() external {
        runTestDeployScript();
        setup_completeCommitteeAndNewMembers();
    }

    function test_triggerOperatorTake_Revert_UserTakeAlreadySigned() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegoutAndMemberNonces();
        setup_addMemberSignature_MultipleMembers(setup.pegoutTxid, 0, registry.committeeMemberCount());

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IOperatorTakeManager.UserTakeAlreadySigned.selector, setup.acceptPeginTxid)
        );

        // Act
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);
    }

    function test_triggerOperatorTake_Revert_PegoutNotFoundForPegin() external {
        // Arrange - use acceptPeginTxid that has no pegoutStartInfo (pegoutTxid will be 0)
        bytes32 wrongAcceptPeginTxid = hex"0001";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.PegoutNotFoundForPegin.selector, wrongAcceptPeginTxid));

        // Act
        operatorTakeManager.triggerOperatorTake(wrongAcceptPeginTxid);
    }

    function test_triggerOperatorTake_Revert_UserTakeTimeoutNotExpired() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegoutAndMemberNonces();
        uint256 createdAt = block.timestamp;
        uint256 expireAt = createdAt + TAKE_0_TIMEOUT_DEFAULT;
        setup_addMemberSignature_MultipleMembers(setup.pegoutTxid, 0, registry.committeeMemberCount() - 1);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IOperatorTakeManager.UserTakeTimeoutNotExpired.selector, createdAt, expireAt)
        );

        // Act
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.LOCKED
        );
    }

    function test_triggerOperatorTake_Success_AllNoncesAdded_NotAllSignatures() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegoutAndMemberNonces();
        uint256 createdAt = block.timestamp;
        // Expire TAKE_0
        vm.warp(createdAt + TAKE_0_TIMEOUT_DEFAULT + 1);
        // This depende on how they have been registered. First registered group are the watchtowers
        uint256 firstHonestOpIndex = registry.committeeMemberCount() / 2 + 1;

        // Add just 2 signatures for the first and second honest operators (index 3 and 4)
        setup_addMemberSignature_MultipleMembers(setup.pegoutTxid, firstHonestOpIndex, 2);

        // Get the last operator take address
        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        uint256 lastOpTakeIndex = committee.operatorTakeIndex;
        uint256 expectedOpTakeIndex = (lastOpTakeIndex + 3) % committee.members.length;
        address expectedOperatorAddress = committee.members[expectedOpTakeIndex].memberAddress;

        uint256 previousSequenceNumber = operatorTakeManager.sequenceNumber();

        // Assert event
        assertEventOperatorTakeTriggered(setup, expectedOperatorAddress);

        // Act
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);

        // Assert status
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );

        assertEq(
            operatorTakeManager.sequenceNumber(), previousSequenceNumber + 1, "Sequence number should be incremented"
        );
    }

    function test_triggerOperatorTake_Success_NotAllNoncesAdded() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegout();
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        uint256 createdAt = block.timestamp;
        // Expire TAKE_0
        vm.warp(createdAt + TAKE_0_TIMEOUT_DEFAULT + 1);

        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        address firstOpAddress = committee.members[0].memberAddress;
        address secondOpAddress = committee.members[1].memberAddress;
        setup_addMemberNonce(firstOpAddress, setup.pegoutTxid, nonce);
        setup_addMemberNonce(secondOpAddress, setup.pegoutTxid, nonce);

        uint256 previousSequenceNumber = operatorTakeManager.sequenceNumber();

        // Assert
        // By implementation, first operator is skipped.
        assertEventOperatorTakeTriggered(setup, secondOpAddress);

        // Act
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);

        // Assert status
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );

        assertEq(
            operatorTakeManager.sequenceNumber(), previousSequenceNumber + 1, "Sequence number should be incremented"
        );
    }

    function test_triggerOperatorTake_Revert_UnauthorizedToTriggerOperatorTake_OnChallenge() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegout();
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        uint256 createdAt = block.timestamp;
        // Expire TAKE_0
        vm.warp(createdAt + TAKE_0_TIMEOUT_DEFAULT + 1);

        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        address firstOpAddress = committee.members[0].memberAddress;
        address secondOpAddress = committee.members[1].memberAddress;
        setup_addMemberNonce(firstOpAddress, setup.pegoutTxid, nonce);
        setup_addMemberNonce(secondOpAddress, setup.pegoutTxid, nonce);

        // On PegStatus.CHALLENGE, only challenge manager can trigger operator take
        vm.prank(address(challengeManager));
        streamManager.setPegStatus(setup.acceptPeginTxid, PegStatus.CHALLENGE);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.CallerIsNotChallengeManager.selector, address(this)));

        // Act
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);
    }

    function test_triggerOperatorTake_Success_OnChallenge() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegout();
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        uint256 createdAt = block.timestamp;
        // Expire TAKE_0
        vm.warp(createdAt + TAKE_0_TIMEOUT_DEFAULT + 1);

        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        address firstOpAddress = committee.members[0].memberAddress;
        address secondOpAddress = committee.members[1].memberAddress;
        setup_addMemberNonce(firstOpAddress, setup.pegoutTxid, nonce);
        setup_addMemberNonce(secondOpAddress, setup.pegoutTxid, nonce);

        // On PegStatus.CHALLENGE, only challenge manager can trigger operator take
        vm.prank(address(challengeManager));
        streamManager.setPegStatus(setup.acceptPeginTxid, PegStatus.CHALLENGE);

        // Act
        vm.prank(address(challengeManager));
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);
    }

    function test_triggerOperatorTake_Revert_UnauthorizedToTriggerOperatorTake_OnRevealed() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegout();
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        uint256 createdAt = block.timestamp;
        // Expire TAKE_0
        vm.warp(createdAt + TAKE_0_TIMEOUT_DEFAULT + 1);

        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        address firstOpAddress = committee.members[0].memberAddress;
        address secondOpAddress = committee.members[1].memberAddress;
        setup_addMemberNonce(firstOpAddress, setup.pegoutTxid, nonce);
        setup_addMemberNonce(secondOpAddress, setup.pegoutTxid, nonce);

        // On PegStatus.REVEALED, only challenge manager can trigger operator take
        vm.prank(address(challengeManager));
        streamManager.setPegStatus(setup.acceptPeginTxid, PegStatus.REVEALED);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IAccessManager.CallerIsNotChallengeManager.selector, address(this)));

        // Act
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);
    }

    function test_triggerOperatorTake_Success_OnRevealed() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegout();
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        uint256 createdAt = block.timestamp;
        // Expire TAKE_0
        vm.warp(createdAt + TAKE_0_TIMEOUT_DEFAULT + 1);

        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        address firstOpAddress = committee.members[0].memberAddress;
        address secondOpAddress = committee.members[1].memberAddress;
        setup_addMemberNonce(firstOpAddress, setup.pegoutTxid, nonce);
        setup_addMemberNonce(secondOpAddress, setup.pegoutTxid, nonce);

        // On PegStatus.REVEALED, only challenge manager can trigger operator take
        vm.prank(address(challengeManager));
        streamManager.setPegStatus(setup.acceptPeginTxid, PegStatus.REVEALED);

        // Act
        vm.prank(address(challengeManager));
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);
    }

    function test_triggerOperatorTake_Revert_OperatorTakeTimeoutNotExpired() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegoutAndMemberNonces();
        setup_addMemberSignature_MultipleMembers(setup.pegoutTxid, 0, registry.committeeMemberCount() - 1);
        vm.warp(block.timestamp + TAKE_0_TIMEOUT_DEFAULT + 1);
        // First call to triggerOperatorTake should set the status to TAKE_1
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IOperatorTakeManager.OperatorTakeTimeoutNotExpired.selector,
                block.timestamp,
                block.timestamp + TAKE_1_TIMEOUT_DEFAULT
            )
        );

        // Act
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );
    }

    function test_triggerOperatorTake_Retrigger_Success_AllNoncesAdded_NotAllSignatures() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegoutAndMemberNonces();
        uint256 createdAt = block.timestamp;
        uint256 firstHonestOpIndex = registry.committeeMemberCount() / 2 + 1;

        // Expire TAKE_0
        vm.warp(createdAt + TAKE_0_TIMEOUT_DEFAULT + 1);
        // Add just 2 signatures for the fisrt and second operators
        setup_addMemberSignature_MultipleMembers(setup.pegoutTxid, firstHonestOpIndex, 2);
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);
        // Expire TAKE_1
        vm.warp(block.timestamp + TAKE_1_TIMEOUT_DEFAULT + 1);
        // Get the last operator take index
        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        uint256 lastOpTakeIndex = committee.operatorTakeIndex;
        uint256 expectedOpTakeIndex = (lastOpTakeIndex + 1) % committee.members.length;
        uint256 previousSequenceNumber = operatorTakeManager.sequenceNumber();

        // Assert
        address expectedOperator = committee.members[expectedOpTakeIndex].memberAddress;
        assertEventOperatorTakeTriggered(setup, expectedOperator);

        // Act
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);

        // Assert status
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );
        assertEq(
            operatorTakeManager.sequenceNumber(), previousSequenceNumber + 1, "Sequence number should be incremented"
        );
    }

    function test_triggerOperatorTake_Retrigger_Success_NotAllNoncesAdded() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegout();
        uint256 createdAt = block.timestamp;
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        // Expire TAKE_0
        vm.warp(createdAt + TAKE_0_TIMEOUT_DEFAULT + 1);
        // Add just 3 nonces
        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        address firstOpAddress = committee.members[0].memberAddress;
        address secondOpAddress = committee.members[1].memberAddress;
        address thirdOpAddress = committee.members[2].memberAddress;
        setup_addMemberNonce(firstOpAddress, setup.pegoutTxid, nonce);
        setup_addMemberNonce(secondOpAddress, setup.pegoutTxid, nonce);
        setup_addMemberNonce(thirdOpAddress, setup.pegoutTxid, nonce);

        // First operator is skipped. This call will select the second operator as in test_triggerOperatorTake_Success_NotAllNoncesAdded
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);
        // Expire TAKE_1
        vm.warp(block.timestamp + TAKE_1_TIMEOUT_DEFAULT + 1);

        // Assert
        // This call will select the third operator
        assertEventOperatorTakeTriggered(setup, thirdOpAddress);

        // Act
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );
    }

    function setup_expireOperatorTakeAndTriggerMultipleTimes() internal returns (bytes32 _pegoutSignatureHash) {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegoutAndMemberNonces();
        uint256 firstHonestOpIndex = registry.committeeMemberCount() / 2;
        uint256 operatorsCount = registry.committeeMemberCount() * 2; // To be sure that we choose operatores multiples times
        setup_addMemberSignature_MultipleMembers(setup.pegoutTxid, firstHonestOpIndex, operatorsCount);
        vm.warp(block.timestamp + TAKE_0_TIMEOUT_DEFAULT + 1);
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);

        for (uint256 i = 0; i < operatorsCount - 1; i++) {
            vm.warp(block.timestamp + TAKE_1_TIMEOUT_DEFAULT + 1);
            operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);
        }

        vm.warp(block.timestamp + TAKE_1_TIMEOUT_DEFAULT + 1);
        return setup.pegoutSignatureHash;
    }

    function test_userTakeTimeout_Success() external view {
        // Act
        uint256 timeout = operatorTakeManager.getTakeTimeout().userTake;

        // Assert
        assertEq(timeout, TAKE_0_TIMEOUT_DEFAULT);
    }

    function test_operatorTakeTimeout_Success() external view {
        // Act
        uint256 timeout = operatorTakeManager.getTakeTimeout().operatorTake;

        // Assert
        assertEq(timeout, TAKE_1_TIMEOUT_DEFAULT);
    }

    function test_setUserTakeTimeout_Success() external {
        // Arrange
        uint256 timeout = TAKE_0_TIMEOUT_DEFAULT + 1 days;
        uint256 opTimeout = operatorTakeManager.getTakeTimeout().operatorTake;

        // Assert
        vm.expectEmit(address(operatorTakeManager));
        emit IOperatorTakeManager.TimeoutsUpdated(timeout, opTimeout);

        // Act
        vm.prank(address(operatorTakeManager.owner()));
        operatorTakeManager.setTakeTimeout(TakeTimeout({userTake: timeout, operatorTake: opTimeout}));

        // Assert
        uint256 newTimeout = operatorTakeManager.getTakeTimeout().userTake;
        assertEq(newTimeout, timeout);
    }

    function test_setOperatorTakeTimeout_Success() external {
        // Arrange
        uint256 userTimeout = operatorTakeManager.getTakeTimeout().userTake;
        uint256 timeout = TAKE_1_TIMEOUT_DEFAULT + 1 days;

        // Assert
        vm.expectEmit(address(operatorTakeManager));
        emit IOperatorTakeManager.TimeoutsUpdated(userTimeout, timeout);

        // Act
        vm.prank(address(operatorTakeManager.owner()));
        operatorTakeManager.setTakeTimeout(TakeTimeout({userTake: userTimeout, operatorTake: timeout}));

        // Assert
        uint256 newTimeout = operatorTakeManager.getTakeTimeout().operatorTake;
        assertEq(newTimeout, timeout);
    }

    function test_setUserTakeTimeout_Revert_InvalidTimeout() external {
        // Arrange
        address owner = operatorTakeManager.owner();
        uint256 opTimeout = operatorTakeManager.getTakeTimeout().operatorTake;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IOperatorTakeManager.InvalidTimeout.selector, 0));

        // Act
        vm.prank(address(owner));
        operatorTakeManager.setTakeTimeout(TakeTimeout({userTake: 0, operatorTake: opTimeout}));
    }

    function test_setOperatorTakeTimeout_Revert_InvalidTimeout() external {
        // Arrange
        address owner = operatorTakeManager.owner();
        uint256 userTimeout = operatorTakeManager.getTakeTimeout().userTake;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IOperatorTakeManager.InvalidTimeout.selector, 0));

        // Act
        vm.prank(address(owner));
        operatorTakeManager.setTakeTimeout(TakeTimeout({userTake: userTimeout, operatorTake: 0}));
    }

    function test_setUserTakeTimeout_Revert_OwnableUnauthorizedAccount() external {
        uint256 opTimeout = operatorTakeManager.getTakeTimeout().operatorTake;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        operatorTakeManager.setTakeTimeout(TakeTimeout({userTake: 1 days, operatorTake: opTimeout}));
    }

    function test_setOperatorTakeTimeout_Revert_OwnableUnauthorizedAccount() external {
        uint256 userTimeout = operatorTakeManager.getTakeTimeout().userTake;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        operatorTakeManager.setTakeTimeout(TakeTimeout({userTake: userTimeout, operatorTake: 1 days}));
    }

    function test_triggerOperatorTake_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegout();
        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);
    }

    function test_triggerOperatorTake_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseContracts();
        RegisterUserTakeSetup memory setup = setup_pegout();
        bytes32 pegoutTxId = setup.pegoutTxid;
        bytes memory nonce =
            hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
        uint256 createdAt = block.timestamp;
        // Expire TAKE_0
        vm.warp(createdAt + TAKE_0_TIMEOUT_DEFAULT + 1);

        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        address firstOpAddress = committee.members[0].memberAddress;
        address secondOpAddress = committee.members[1].memberAddress;
        setup_addMemberNonce(firstOpAddress, pegoutTxId, nonce);
        setup_addMemberNonce(secondOpAddress, pegoutTxId, nonce);

        // Assert
        assertEventOperatorTakeTriggered(setup, secondOpAddress);

        // Act
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);
    }

    function test_setUserTakeTimeout_Success_PausedContract() external {
        // Arrange
        pauseContracts();

        uint256 timeout = TAKE_0_TIMEOUT_DEFAULT + 1 days;
        address owner = operatorTakeManager.owner();
        uint256 opTimeout = operatorTakeManager.getTakeTimeout().operatorTake;

        // Assert
        vm.expectEmit(address(operatorTakeManager));
        emit IOperatorTakeManager.TimeoutsUpdated(timeout, opTimeout);

        // Act
        vm.prank(owner);
        operatorTakeManager.setTakeTimeout(TakeTimeout({userTake: timeout, operatorTake: opTimeout}));
    }

    function test_setOperatorTakeTimeout_Success_PausedContract() external {
        // Arrange
        pauseContracts();

        uint256 userTimeout = operatorTakeManager.getTakeTimeout().userTake;
        uint256 timeout = TAKE_1_TIMEOUT_DEFAULT + 1 days;
        address owner = operatorTakeManager.owner();

        // Assert
        vm.expectEmit(address(operatorTakeManager));
        emit IOperatorTakeManager.TimeoutsUpdated(userTimeout, timeout);

        // Act
        vm.prank(owner);
        operatorTakeManager.setTakeTimeout(TakeTimeout({userTake: userTimeout, operatorTake: timeout}));
    }

    function test_triggerOperatorTake_Success_FromAdvanced() external {
        // Arrange - setup_reimbursementKickoff brings state to ADVANCED
        (, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();
        uint256 createdAt = block.timestamp;
        // Expire the operator take timeout
        vm.warp(createdAt + TAKE_1_TIMEOUT_DEFAULT + 1);

        // Get the expected next operator
        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        uint256 expectedOpTakeIndex = (committee.operatorTakeIndex + 1) % committee.members.length;
        address expectedOperatorAddress = committee.members[expectedOpTakeIndex].memberAddress;

        // Assert
        assertEventOperatorTakeTriggered(setup, expectedOperatorAddress);

        // Act
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);

        // Assert - status should be reset to OP_SELECTED
        StreamPosition memory updatedStreamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertTrue(updatedStreamInfo.pegStatus == PegStatus.OP_SELECTED, "PegStatus should be reset to OP_SELECTED");
    }

    function test_triggerOperatorTake_Success_FromKickoff() external {
        // Arrange - setup_operatorTake brings state to KICKOFF
        (, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        uint256 createdAt = block.timestamp;
        // Expire the operator take timeout
        vm.warp(createdAt + TAKE_1_TIMEOUT_DEFAULT + 1);

        // Get the expected next operator
        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        uint256 expectedOpTakeIndex = (committee.operatorTakeIndex + 1) % committee.members.length;
        address expectedOperatorAddress = committee.members[expectedOpTakeIndex].memberAddress;

        // Assert
        assertEventOperatorTakeTriggered(setup, expectedOperatorAddress);

        // Act
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);

        // Assert - status should be reset to OP_SELECTED
        StreamPosition memory updatedStreamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertTrue(updatedStreamInfo.pegStatus == PegStatus.OP_SELECTED, "PegStatus should be reset to OP_SELECTED");
    }

    function test_triggerOperatorTake_FromAdvanced_Revert_OperatorTakeTimeoutNotExpired() external {
        // Arrange - setup_reimbursementKickoff brings state to ADVANCED
        (, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();

        // Get operatorTakeUpdatedAt
        OperatorTakeInfo memory opInfo = operatorTakeManager.getOperatorTakeInfo(setup.acceptPeginTxid);
        uint256 operatorTakeUpdatedAt = opInfo.operatorTakeUpdatedAt;

        // Assert - should revert because timeout hasn't expired
        vm.expectRevert(
            abi.encodeWithSelector(
                IOperatorTakeManager.OperatorTakeTimeoutNotExpired.selector,
                operatorTakeUpdatedAt,
                operatorTakeUpdatedAt + TAKE_1_TIMEOUT_DEFAULT
            )
        );
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);
    }

    function test_triggerOperatorTake_FromKickoff_Revert_OperatorTakeTimeoutNotExpired() external {
        // Arrange - setup_operatorTake brings state to KICKOFF
        (, RegisterUserTakeSetup memory setup) = setup_operatorTake();

        // Get operatorTakeUpdatedAt
        OperatorTakeInfo memory opInfo = operatorTakeManager.getOperatorTakeInfo(setup.acceptPeginTxid);
        uint256 operatorTakeUpdatedAt = opInfo.operatorTakeUpdatedAt;

        // Assert - should revert because timeout hasn't expired
        vm.expectRevert(
            abi.encodeWithSelector(
                IOperatorTakeManager.OperatorTakeTimeoutNotExpired.selector,
                operatorTakeUpdatedAt,
                operatorTakeUpdatedAt + TAKE_1_TIMEOUT_DEFAULT
            )
        );
        operatorTakeManager.triggerOperatorTake(setup.acceptPeginTxid);
    }

    function test_registerReimbursementKickoff_Revert_BaseEventAlreadySet() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        pauseAndUnpauseContracts();
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();

        // Set a base event directly on the bridge mock to simulate it already being set
        vm.prank(address(rbtcBridge));
        bridgeMock.setBaseEvent("existing base event");

        // Assert - should revert because base event is already set
        vm.expectRevert(IRbtcBridge.BaseEventAlreadySet.selector);

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);
    }

    function test_registerAdvanceFunds_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseContracts();
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_advanceFunds();
        bytes32 txid = bitcoinManager.getBtcTxid(setup.advanceFundsSPV.btcTx);
        StreamPosition memory streamInfo = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.OP_SELECTED
        });

        OperatorTakeInfo memory opInfo = operatorTakeManager.getOperatorTakeInfo(setup.acceptPeginTxid);

        // Assert
        vm.expectEmit(address(operatorTakeManager));
        emit IOperatorTakeManager.AdvanceFundsRegistered(
            setup.advanceFundsSPV.blockHash,
            txid,
            setup.acceptPeginTxid,
            setup.pegoutId,
            COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            streamInfo,
            opInfo.operatorTakePubKey
        );

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerAdvanceFunds(setup.acceptPeginTxid, setup.advanceFundsSPV);

        streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.ADVANCED));
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
            "Slot state should be ADVANCED"
        );

        OperatorTakeInfo memory updatedOpInfo = operatorTakeManager.getOperatorTakeInfo(setup.acceptPeginTxid);
        assertEq(updatedOpInfo.operatorTakeUpdatedAt, block.timestamp, "operatorTakeUpdatedAt should be updated");
    }

    function test_registerAdvanceFunds_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_advanceFunds();
        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerAdvanceFunds(setup.acceptPeginTxid, setup.advanceFundsSPV);
    }

    function test_registerAdvanceFunds_Revert_PeginNotRequested() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_advanceFunds();
        bytes32 wrongAcceptPeginTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegBase.PeginNotRequested.selector, wrongAcceptPeginTxid));

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerAdvanceFunds(wrongAcceptPeginTxid, setup.advanceFundsSPV);
    }

    function test_registerAdvanceFunds_Revert_WrongUserAmount() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_advanceFunds();

        BtcTxSPVProof memory wrongSPV =
            createBtcTxSPVProof(createAdvanceFundsTx(setup.userPubKey, VALUE - 1, setup.pegoutId));

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IOperatorTakeManager.WrongUserAmount.selector,
                setup.advanceFundsSPV.btcTx.outputs[0].amount - 1,
                setup.advanceFundsSPV.btcTx.outputs[0].amount
            )
        );

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerAdvanceFunds(setup.acceptPeginTxid, wrongSPV);
    }

    function test_registerAdvanceFunds_Revert_IncorrectOutputScript_WrongPegoutId() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_advanceFunds();

        BtcTxSPVProof memory wrongSPV = createBtcTxSPVProof(createAdvanceFundsTx(setup.userPubKey, VALUE, hex"00"));

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IPegoutManager.IncorrectOutputScript.selector,
                hex"6a0000000000000000000000000000000000000000000000000000000000000000",
                hex"6a650e1d9986edd152e2d5e79db02b1ad983cd1e31d7d59d62b7bfa0daf697cdcc"
            )
        );

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerAdvanceFunds(setup.acceptPeginTxid, wrongSPV);
    }

    function test_registerAdvanceFunds_Revert_IncorrectOutputScript_WrongUserPubKey() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_advanceFunds();
        bytes32 operatorPubKey = getMemberDisputePubKey(opAddress);
        bytes memory operatorDisputePubKeyCompact = BtcHelper.pubKeyXonlyToCompact(operatorPubKey);

        BtcTxSPVProof memory wrongSPV =
            createBtcTxSPVProof(createAdvanceFundsTx(operatorDisputePubKeyCompact, VALUE, setup.pegoutId));

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IPegoutManager.IncorrectOutputScript.selector,
                hex"0014044b3b919af8d1cc9e50c83d90f506b2caa19f24",
                hex"00143fd2e14f4b448a071e074e1e1879318447f2a266"
            )
        );

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerAdvanceFunds(setup.acceptPeginTxid, wrongSPV);
    }

    function test_registerAdvanceFunds_Revert_OperatorTakeAddressNotMatch() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_advanceFunds();
        address wrongAddress = address(this);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IOperatorTakeManager.OperatorTakeAddressNotMatch.selector, opAddress, wrongAddress)
        );

        // Act
        vm.prank(wrongAddress);
        operatorTakeManager.registerAdvanceFunds(setup.acceptPeginTxid, setup.advanceFundsSPV);
    }

    function test_registerAdvanceFunds_Revert_InvalidPegStatus() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_advanceFunds();

        // Set peg status to COMPLETED to trigger invalid status error
        vm.prank(address(pegoutManager));
        streamManager.setPegStatus(setup.acceptPeginTxid, PegStatus.COMPLETED);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegBase.InvalidPegStatus.selector, PegStatus.COMPLETED));

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerAdvanceFunds(setup.acceptPeginTxid, setup.advanceFundsSPV);
    }

    function test_registerReimbursementKickoff_Success_UnpausedContract() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        pauseAndUnpauseContracts();
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();
        bytes32 txid = bitcoinManager.getBtcTxid(setup.reimbursementKickoffSPV.btcTx);
        StreamPosition memory streamInfo = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.ADVANCED
        });

        // Get the expected pegoutId from the operator take info
        OperatorTakeInfo memory opInfo = operatorTakeManager.getOperatorTakeInfo(setup.acceptPeginTxid);
        bytes memory expectedBaseEvent = abi.encodePacked(opInfo.pegoutId);

        // Assert - expect ReimbursementKickoffRegistered event
        vm.expectEmit(address(operatorTakeManager));
        emit IOperatorTakeManager.ReimbursementKickoffRegistered(
            txid,
            setup.acceptPeginTxid,
            opInfo.pegoutId,
            COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            streamInfo,
            opInfo.operatorTakePubKey
        );

        // Assert - expect BaseEventSet event from RbtcBridge
        vm.expectEmit(address(rbtcBridge));
        emit IRbtcBridge.BaseEventSet(expectedBaseEvent);

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);

        // Verify peg status was updated
        streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.KICKOFF));
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
            "Slot state should be ADVANCED"
        );
        // Get updated opInfo after the call to verify reimbursementKickoffTxid was set
        OperatorTakeInfo memory updatedOpInfo = operatorTakeManager.getOperatorTakeInfo(setup.acceptPeginTxid);
        assertEq(updatedOpInfo.reimbursementKickoffTxid, txid, "Reimbursement kickoff txid should be recorded");
        assertEq(updatedOpInfo.operatorTakeUpdatedAt, block.timestamp, "operatorTakeUpdatedAt should be updated");

        // Assert - verify base event was set correctly in bridge
        bytes memory retrievedBaseEvent = bridgeMock.getBaseEvent();
        assertEq(retrievedBaseEvent.length, expectedBaseEvent.length, "Base event length should match");
        assertEq(
            keccak256(retrievedBaseEvent), keccak256(expectedBaseEvent), "Base event content should match pegoutId"
        );
    }

    function test_registerReimbursementKickoff_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();
        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);
    }

    function test_registerReimbursementKickoff_Revert_PeginNotRequested() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();
        bytes32 wrongAcceptPeginTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegBase.PeginNotRequested.selector, wrongAcceptPeginTxid));

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerReimbursementKickoff(wrongAcceptPeginTxid, setup.reimbursementKickoffSPV);
    }

    function test_registerReimbursementKickoff_Revert_InvalidPegStatus() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();

        // Set peg status to COMPLETED to trigger invalid status error
        vm.prank(address(pegoutManager));
        streamManager.setPegStatus(setup.acceptPeginTxid, PegStatus.COMPLETED);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegBase.InvalidPegStatus.selector, PegStatus.COMPLETED));

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);
    }

    function test_registerReimbursementKickoff_Revert_InvalidSlotId() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();
        uint32 slotId = setup.reimbursementKickoffSPV.btcTx.inputs[Constants.KICKOFF_VIN_SLOT_ID].vout;
        setup.reimbursementKickoffSPV.btcTx.inputs[Constants.KICKOFF_VIN_SLOT_ID].vout += 1; // Modify the tx to break slot id check

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IOperatorTakeManager.InvalidSlotId.selector, slotId + 1, slotId));

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);
    }

    function test_registerReimbursementKickoff_Revert_InvalidKickoffInputCount() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();
        BtcTxIn[] memory modifiedInputs = new BtcTxIn[](setup.reimbursementKickoffSPV.btcTx.inputs.length + 1);
        for (uint256 i = 0; i < setup.reimbursementKickoffSPV.btcTx.inputs.length; i++) {
            modifiedInputs[i] = setup.reimbursementKickoffSPV.btcTx.inputs[i];
        }
        modifiedInputs[modifiedInputs.length - 1] = BtcTxIn({
            txId: 0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd,
            vout: 0,
            sequence: 4294967295,
            scriptSig: hex""
        });
        setup.reimbursementKickoffSPV.btcTx.inputs = modifiedInputs;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IOperatorTakeManager.InvalidKickoffInputCount.selector,
                Constants.KICKOFF_INPUT_COUNT + 1,
                Constants.KICKOFF_INPUT_COUNT
            )
        );

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);
    }

    function test_registerReimbursementKickoff_Success_BaseEventContainsPegoutId() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        pauseAndUnpauseContracts();
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();

        // Get the pegoutId from the operator take info before calling registerReimbursementKickoff
        OperatorTakeInfo memory opInfoBefore = operatorTakeManager.getOperatorTakeInfo(setup.acceptPeginTxid);
        bytes32 expectedPegoutId = opInfoBefore.pegoutId;

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);

        // Assert - verify base event contains the pegoutId (32 bytes)
        bytes memory retrievedBaseEvent = bridgeMock.getBaseEvent();
        assertEq(retrievedBaseEvent.length, 32, "Base event should be 32 bytes (pegoutId)");

        // Extract the pegoutId from the base event
        bytes32 retrievedPegoutId;
        assembly {
            retrievedPegoutId := mload(add(retrievedBaseEvent, 32))
        }
        assertEq(retrievedPegoutId, expectedPegoutId, "Base event should contain the correct pegoutId");
    }

    function test_registerReimbursementKickoff_Success_BaseEventIs32Bytes() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        pauseAndUnpauseContracts();
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);

        // Assert - verify base event is exactly 32 bytes (size of bytes32 pegoutId)
        bytes memory retrievedBaseEvent = bridgeMock.getBaseEvent();
        assertEq(retrievedBaseEvent.length, 32, "Base event should be exactly 32 bytes (pegoutId)");
    }

    function test_registerOperatorWon_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseContracts();
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_inputRevealed();
        bytes32 txid = bitcoinManager.getBtcTxid(setup.operatorWonSPV.btcTx);
        StreamPosition memory streamInfo = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.REVEALED
        });

        vm.expectEmit(address(operatorTakeManager));
        emit IPegoutManager.PegoutRegistered(
            setup.operatorWonSPV.blockHash, txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
        );

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerOperatorWon(setup.operatorWonSPV);

        streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.COMPLETED));
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.COMPLETED,
            "Slot state should be COMPLETED"
        );
    }

    function test_registerOperatorWon_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_inputRevealed();
        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerOperatorWon(setup.operatorWonSPV);
    }

    function test_registerOperatorWon_Revert_PeginNotRequested() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_inputRevealed();
        bytes32 wrongAcceptPeginTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        bytes32 operatorPubKey = getMemberDisputePubKey(opAddress);
        bytes memory operatorDisputePubKeyCompact = BtcHelper.pubKeyXonlyToCompact(operatorPubKey);

        bytes32 inputRevealedTxid = bitcoinManager.getBtcTxid(setup.inputRevealedSPV.btcTx);
        BtcTxSPVProof memory wrongOperatorWonSPV = createBtcTxSPVProof(
            createOperatorWonTx(wrongAcceptPeginTxid, inputRevealedTxid, operatorDisputePubKeyCompact, VALUE)
        );

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegBase.PeginNotRequested.selector, wrongAcceptPeginTxid));

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerOperatorWon(wrongOperatorWonSPV);
    }

    function test_registerOperatorWon_Revert_InvalidPegStatus() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_inputRevealed();

        // Set peg status to COMPLETED to trigger invalid status error
        vm.prank(address(pegoutManager));
        streamManager.setPegStatus(setup.acceptPeginTxid, PegStatus.COMPLETED);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegBase.InvalidPegStatus.selector, PegStatus.COMPLETED));

        // Act
        vm.prank(opAddress);
        operatorTakeManager.registerOperatorWon(setup.operatorWonSPV);
    }

    function test_registerOperatorTake_Success() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 operatorTakeTxid = bitcoinManager.getBtcTxid(setup.operatorTakeSPV.btcTx);

        StreamPosition memory streamInfo = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.KICKOFF
        });

        // Expect the PegoutRegistered event
        vm.expectEmit(address(operatorTakeManager));
        emit IPegoutManager.PegoutRegistered(
            setup.operatorTakeSPV.blockHash,
            operatorTakeTxid,
            setup.acceptPeginTxid,
            COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            streamInfo
        );

        // Act
        vm.prank(operatorAddress);
        operatorTakeManager.registerOperatorTake(setup.operatorTakeSPV);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.COMPLETED
        );
    }

    function test_registerOperatorTake_Success_LastSlot() external {
        // Arrange: Complete all slots except the last one (99 slots) using user take flow
        setup_multiplePegFlows(Constants.SLOTS_PER_PACKET - 1);

        // Setup the last slot (slot 99) with operator take
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 txid = bitcoinManager.getBtcTxid(setup.operatorTakeSPV.btcTx);

        StreamPosition memory streamInfo = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.KICKOFF
        });

        // Verify we're on the last slot
        assertEq(setup.slotId, Constants.SLOTS_PER_PACKET - 1, "Should be the last slot");

        // Expect both PegoutRegistered and PacketClosed events
        vm.expectEmit(address(operatorTakeManager));
        emit IPegoutManager.PegoutRegistered(
            setup.operatorTakeSPV.blockHash, txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
        );

        vm.expectEmit(address(streamManager));
        emit IStreamManager.PacketClosed(setup.stream.streamId, setup.packetNumber);

        // Act: Register the operator take for the last slot
        vm.prank(operatorAddress);
        operatorTakeManager.registerOperatorTake(setup.operatorTakeSPV);

        // Assert: Verify the slot was marked as COMPLETED
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.COMPLETED,
            "Slot should be marked as COMPLETED"
        );
    }

    function test_registerOperatorTake_Revert_PeginNotRequested() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 operatorPubKey = getMemberDisputePubKey(operatorAddress);
        bytes32 wrongAcceptPeginTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

        bytes32 reimbursementTxid = bitcoinManager.getBtcTxid(setup.reimbursementKickoffSPV.btcTx);

        BtcTransaction memory operatorTakeTx = createOperatorTakeTx(
            wrongAcceptPeginTxid, reimbursementTxid, BtcHelper.pubKeyXonlyToCompact(operatorPubKey), VALUE
        );
        BtcTxSPVProof memory operatorTakeSPV = createBtcTxSPVProof(operatorTakeTx);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegBase.PeginNotRequested.selector, wrongAcceptPeginTxid));

        // Act
        vm.prank(operatorAddress);
        operatorTakeManager.registerOperatorTake(operatorTakeSPV);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );
    }

    function test_registerOperatorTake_Revert_InvalidPegStatus() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();

        peginManager.setStreamPositionHarness(
            setup.acceptPeginTxid, setup.stream.streamId, setup.packetNumber, setup.slotId, PegStatus.COMPLETED
        );

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegBase.InvalidPegStatus.selector, PegStatus.COMPLETED));

        // Act
        vm.prank(operatorAddress);
        operatorTakeManager.registerOperatorTake(setup.operatorTakeSPV);
    }

    function test_registerOperatorTake_Revert_IncorrectVout() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        setup.operatorTakeSPV.btcTx.inputs[0].vout = Constants.ACCEPT_PEGIN_VOUT_TAPTREE + 1; // Set an incorrect vout

        vm.expectRevert(
            abi.encodeWithSelector(
                IPegoutManager.IncorrectVout.selector,
                Constants.ACCEPT_PEGIN_VOUT_TAPTREE + 1,
                Constants.ACCEPT_PEGIN_VOUT_TAPTREE
            )
        );

        // Act
        vm.prank(operatorAddress);
        operatorTakeManager.registerOperatorTake(setup.operatorTakeSPV);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );
    }

    function test_registerOperatorTake_Revert_IncorrectOutputScript() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 operatorPubKey = getMemberDisputePubKey(operatorAddress);
        address wrongOperator = vm.addr(1);
        bytes32 wrongOperatorPubKey = getMemberDisputePubKey(wrongOperator);

        bytes32 reimbursementTxid = bitcoinManager.getBtcTxid(setup.reimbursementKickoffSPV.btcTx);

        BtcTransaction memory operatorTakeTx = createOperatorTakeTx(
            setup.acceptPeginTxid, reimbursementTxid, BtcHelper.pubKeyXonlyToCompact(wrongOperatorPubKey), VALUE
        );
        BtcTxSPVProof memory operatorTakeSPV = createBtcTxSPVProof(operatorTakeTx);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPegoutManager.IncorrectOutputScript.selector,
                BtcScriptParser.getP2WPKHScript(BtcHelper.pubKeyXonlyToCompact(wrongOperatorPubKey)),
                BtcScriptParser.getP2WPKHScript(BtcHelper.pubKeyXonlyToCompact(operatorPubKey))
            )
        );

        // Act
        vm.prank(operatorAddress);
        operatorTakeManager.registerOperatorTake(operatorTakeSPV);

        // Assert
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );
    }

    function test_registerOperatorTake_Revert_OperatorTakeAddressNotMatch() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        address wrongOperator = vm.addr(1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IOperatorTakeManager.OperatorTakeAddressNotMatch.selector, operatorAddress, wrongOperator
            )
        );

        // Act
        vm.prank(wrongOperator);
        operatorTakeManager.registerOperatorTake(setup.operatorTakeSPV);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );
    }

    function test_registerOperatorTake_Revert_OperatorTakeTxidNotMatch() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 operatorPubKey = getMemberDisputePubKey(operatorAddress);
        bytes32 realTakeTxid = bitcoinManager.getBtcTxid(setup.operatorTakeSPV.btcTx);

        bytes32 reimbursementTxid = bitcoinManager.getBtcTxid(setup.reimbursementKickoffSPV.btcTx);

        BtcTransaction memory operatorTakeTx = createOperatorTakeTx(
            setup.acceptPeginTxid, reimbursementTxid, BtcHelper.pubKeyXonlyToCompact(operatorPubKey), VALUE
        );
        operatorTakeTx.outputs[1].amount += 1000; // Modify the tx to produce a different txid

        bytes32 wrongTakeTxid = bitcoinManager.getBtcTxid(operatorTakeTx);
        BtcTxSPVProof memory operatorTakeSPV = createBtcTxSPVProof(operatorTakeTx);

        vm.expectRevert(
            abi.encodeWithSelector(IOperatorTakeManager.OperatorTakeTxidNotMatch.selector, wrongTakeTxid, realTakeTxid)
        );

        // Act
        vm.prank(operatorAddress);
        operatorTakeManager.registerOperatorTake(operatorTakeSPV);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );
    }

    function test_registerOperatorTake_Revert_InvalidSlotState() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        // Set slot as COMPLETED
        streamManager.setSlotStateHarness(setup.stream.streamId, setup.packetNumber, setup.slotId, SlotState.COMPLETED);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.InvalidSlotState.selector, SlotState.COMPLETED, SlotState.LOCKED)
        );

        // Act
        vm.prank(operatorAddress);
        operatorTakeManager.registerOperatorTake(setup.operatorTakeSPV);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.COMPLETED
        );
    }

    function test_registerOperatorTake_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();

        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(operatorAddress);
        operatorTakeManager.registerOperatorTake(setup.operatorTakeSPV);
    }

    function test_registerOperatorTake_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseContracts();
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();

        // Act
        vm.prank(operatorAddress);
        operatorTakeManager.registerOperatorTake(setup.operatorTakeSPV);
    }
}
