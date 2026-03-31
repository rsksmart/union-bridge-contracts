// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {Constants} from "src/libraries/Constants.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IPegBase} from "src/interfaces/IPegBase.sol";
import {BtcTxSPVProof, StreamPosition} from "src/interfaces/IPegCommonTypes.sol";
import {PegStatus} from "src/interfaces/IPegCommonTypes.sol";
import {ChallengeInfo, IChallengeManager} from "src/interfaces/IChallengeManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {CompactPubKey} from "src/interfaces/IMemberRegistry.sol";
import {SlotState} from "src/interfaces/IStreamManager.sol";
import {BtcTxIn, BtcTxOut} from "src/interfaces/IBitcoinManager.sol";

contract ChallengeManagerTest is Test, HelperContract {
    function setUp() external {
        runTestDeployScript();
        setup_completeCommitteeAndNewMembers();
    }

    // ============ Initialization Tests ============

    function test_initialize_Success() external view {
        // Assert - verify initialization state
        assertTrue(challengeManager.owner() != address(0)); // Owner should be set
        assertEq(challengeManager.pauser(), address(accessManager)); // Pauser should be set to accessManager
        assertEq(address(challengeManager.committeeRegistry()), address(registry));
        assertEq(address(challengeManager.bitcoinManager()), address(bitcoinManager));
        assertEq(address(challengeManager.streamManager()), address(streamManager));
        assertEq(address(challengeManager.rbtcBridge()), address(rbtcBridge));
    }

    function test_registerChallenge_Success_OperatorCall() external {
        // Arrange
        pauseAndUnpauseContracts();
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 txid = bitcoinManager.getBtcTxid(setup.challengeSPV.btcTx);
        StreamPosition memory streamInfo = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.KICKOFF
        });

        vm.expectEmit(address(challengeManager));
        emit IChallengeManager.ChallengeRegistered(
            txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
        );

        // Act
        vm.prank(opAddress);
        challengeManager.registerChallenge(setup.acceptPeginTxid, setup.challengeSPV);

        // Assert
        streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.CHALLENGE), "PegStatus should be CHALLENGE");
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
            "Slot state should be ADVANCED"
        );
        ChallengeInfo memory challengeInfo = challengeManager.getChallengeInfo(setup.acceptPeginTxid);
        assertEq(challengeInfo.challengeTxid, txid, "Challenge txid should be recorded");
    }

    function test_registerChallenge_Success_MemberCall() external {
        // Arrange
        pauseAndUnpauseContracts();
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 txid = bitcoinManager.getBtcTxid(setup.challengeSPV.btcTx);
        StreamPosition memory streamInfo = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.KICKOFF
        });

        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        vm.expectEmit(address(challengeManager));
        emit IChallengeManager.ChallengeRegistered(
            txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
        );

        // Act
        vm.prank(memberAddress);
        challengeManager.registerChallenge(setup.acceptPeginTxid, setup.challengeSPV);

        // Assert
        streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.CHALLENGE), "PegStatus should be CHALLENGE");
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
            "Slot state should be ADVANCED"
        );
        ChallengeInfo memory challengeInfo = challengeManager.getChallengeInfo(setup.acceptPeginTxid);
        assertEq(challengeInfo.challengeTxid, txid, "Challenge txid should be recorded");
    }

    function test_registerChallenge_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");
        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(memberAddress);
        challengeManager.registerChallenge(setup.acceptPeginTxid, setup.challengeSPV);
    }

    function test_registerChallenge_Revert_PeginNotRequested() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 wrongAcceptPeginTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegBase.PeginNotRequested.selector, wrongAcceptPeginTxid));

        // Act
        vm.prank(memberAddress);
        challengeManager.registerChallenge(wrongAcceptPeginTxid, setup.challengeSPV);
    }

    function test_registerChallenge_Revert_InvalidPegStatus() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        // Set peg status to COMPLETED to trigger invalid status error
        vm.prank(address(challengeManager));
        streamManager.setPegStatus(setup.acceptPeginTxid, PegStatus.COMPLETED);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegBase.InvalidPegStatus.selector, PegStatus.COMPLETED));

        // Act
        vm.prank(memberAddress);
        challengeManager.registerChallenge(setup.acceptPeginTxid, setup.challengeSPV);
    }

    function test_registerChallenge_Revert_ReimbursementKickoffTxidNotMatch() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 txid = bitcoinManager.getBtcTxid(setup.reimbursementKickoffSPV.btcTx);
        bytes32 wrongTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        uint128 committeeId = streamManager.getCommitteeId(uint64(DEFAULT_STREAM), setup.packetNumber);
        bytes memory committeePubKey = registry.getCommitteeTakePubKey(committeeId);
        BtcTxSPVProof memory wrongSPV = createBtcTxSPVProof(createChallengeTx(wrongTxid, committeePubKey));
        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IChallengeManager.ReimbursementKickoffTxidNotMatch.selector, wrongTxid, txid)
        );

        // Act
        vm.prank(memberAddress);
        challengeManager.registerChallenge(setup.acceptPeginTxid, wrongSPV);
    }

    function test_registerChallenge_Revert_MemberNotInCommittee() external {
        // Arrange
        (, RegisterUserTakeSetup memory setup) = setup_operatorTake();

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberNotInCommittee.selector, COMMITTEE_ID_STREAM_1_COMMITTEE_1, address(this)
            )
        );

        // Act
        challengeManager.registerChallenge(setup.acceptPeginTxid, setup.challengeSPV);
    }

    function test_registerInputRevealed_Success_OperatorCall() external {
        // Arrange
        pauseAndUnpauseContracts();
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        bytes32 txid = bitcoinManager.getBtcTxid(setup.inputRevealedSPV.btcTx);
        StreamPosition memory streamInfo = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.CHALLENGE
        });

        vm.expectEmit(address(challengeManager));
        emit IChallengeManager.RevealRegistered(
            txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
        );

        // Act
        vm.prank(opAddress);
        challengeManager.registerInputRevealed(setup.acceptPeginTxid, setup.inputRevealedSPV);

        // Assert
        streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.REVEALED), "PegStatus should be REVEALED");

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
            "Slot state should be ADVANCED"
        );

        ChallengeInfo memory challengeInfo = challengeManager.getChallengeInfo(setup.acceptPeginTxid);
        assertEq(challengeInfo.revealTxid, txid, "Input revealed txid should be recorded");
    }

    function test_registerInputRevealed_Success_MemberCall() external {
        // Arrange
        pauseAndUnpauseContracts();
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        bytes32 txid = bitcoinManager.getBtcTxid(setup.inputRevealedSPV.btcTx);
        StreamPosition memory streamInfo = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.CHALLENGE
        });

        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        vm.expectEmit(address(challengeManager));
        emit IChallengeManager.RevealRegistered(
            txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
        );

        // Act
        vm.prank(memberAddress);
        challengeManager.registerInputRevealed(setup.acceptPeginTxid, setup.inputRevealedSPV);

        // Assert
        streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.REVEALED), "PegStatus should be REVEALED");

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
            "Slot state should be ADVANCED"
        );

        ChallengeInfo memory challengeInfo = challengeManager.getChallengeInfo(setup.acceptPeginTxid);
        assertEq(challengeInfo.revealTxid, txid, "Input revealed txid should be recorded");
    }

    function test_registerInputRevealed_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(opAddress);
        challengeManager.registerInputRevealed(setup.acceptPeginTxid, setup.inputRevealedSPV);
    }

    function test_registerInputRevealed_Revert_PeginNotRequested() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        bytes32 wrongAcceptPeginTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegBase.PeginNotRequested.selector, wrongAcceptPeginTxid));

        // Act
        vm.prank(opAddress);
        challengeManager.registerInputRevealed(wrongAcceptPeginTxid, setup.inputRevealedSPV);
    }

    function test_registerInputRevealed_Revert_InvalidPegStatus() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();

        // Set peg status to COMPLETED to trigger invalid status error
        vm.prank(address(challengeManager));
        streamManager.setPegStatus(setup.acceptPeginTxid, PegStatus.COMPLETED);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegBase.InvalidPegStatus.selector, PegStatus.COMPLETED));

        // Act
        vm.prank(opAddress);
        challengeManager.registerInputRevealed(setup.acceptPeginTxid, setup.inputRevealedSPV);
    }

    function test_registerInputRevealed_Revert_ChallengeTxidNotMatch() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        bytes32 txid = bitcoinManager.getBtcTxid(setup.challengeSPV.btcTx);
        bytes32 wrongTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        uint128 committeeId = streamManager.getCommitteeId(uint64(DEFAULT_STREAM), setup.packetNumber);
        bytes memory committeePubKey = registry.getCommitteeTakePubKey(committeeId);
        bytes memory operatorPubKey = BtcHelper.compactPubKeyToBytes(memberRegistry.getMemberDisputePubKey(opAddress));

        BtcTxSPVProof memory wrongSPV =
            createBtcTxSPVProof(createInputRevealedTx(wrongTxid, committeePubKey, operatorPubKey));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IChallengeManager.ChallengeTxidNotMatch.selector, wrongTxid, txid));

        // Act
        vm.prank(opAddress);
        challengeManager.registerInputRevealed(setup.acceptPeginTxid, wrongSPV);
    }

    function test_registerInputRevealed_Revert_InvalidRevealedInputCount() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        BtcTxIn[] memory wrongInputCount = new BtcTxIn[](0);
        setup.inputRevealedSPV.btcTx.inputs = wrongInputCount;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IChallengeManager.InvalidRevealedInputCount.selector, 0, Constants.INPUT_REVEALED_INPUT_COUNT
            )
        );

        // Act
        vm.prank(memberAddress);
        challengeManager.registerInputRevealed(setup.acceptPeginTxid, setup.inputRevealedSPV);
    }

    function test_registerInputRevealed_Revert_InvalidRevealedOutputCount() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        BtcTxOut[] memory wrongOutputCount = new BtcTxOut[](0);
        setup.inputRevealedSPV.btcTx.outputs = wrongOutputCount;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IChallengeManager.InvalidRevealedOutputCount.selector, 0, Constants.INPUT_REVEALED_OUTPUT_COUNT
            )
        );

        // Act
        vm.prank(memberAddress);
        challengeManager.registerInputRevealed(setup.acceptPeginTxid, setup.inputRevealedSPV);
    }

    function test_registerInputRevealed_Revert_MemberNotInCommittee() external {
        // Arrange
        (, RegisterUserTakeSetup memory setup) = setup_challenge();

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberNotInCommittee.selector, COMMITTEE_ID_STREAM_1_COMMITTEE_1, address(this)
            )
        );

        // Act
        challengeManager.registerInputRevealed(setup.acceptPeginTxid, setup.inputRevealedSPV);
    }

    function test_registerInputNotRevealed_Success_OperatorCall() external {
        // Arrange
        pauseAndUnpauseContracts();
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        bytes32 txid = bitcoinManager.getBtcTxid(setup.inputNotRevealedSPV.btcTx);
        StreamPosition memory streamInfo = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.CHALLENGE
        });

        vm.expectEmit(address(challengeManager));
        emit IChallengeManager.InputNotRevealedRegistered(
            txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
        );

        // Act
        vm.prank(opAddress);
        challengeManager.registerInputNotRevealed(setup.acceptPeginTxid, setup.inputNotRevealedSPV);

        // Assert
        streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.OP_SELECTED), "PegStatus should be OP_SELECTED");

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
            "Slot state should be ADVANCED"
        );

        // getChallengeInfo will revert as challengeTxid was deleted and trigger operator take triggered
        vm.expectRevert(abi.encodeWithSelector(IChallengeManager.NoChallengeRegistered.selector, setup.acceptPeginTxid));
        challengeManager.getChallengeInfo(setup.acceptPeginTxid);
    }

    function test_registerInputNotRevealed_Success_MemberCall() external {
        // Arrange
        pauseAndUnpauseContracts();
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        bytes32 txid = bitcoinManager.getBtcTxid(setup.inputNotRevealedSPV.btcTx);
        StreamPosition memory streamInfo = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.CHALLENGE
        });

        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        vm.expectEmit(address(challengeManager));
        emit IChallengeManager.InputNotRevealedRegistered(
            txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
        );

        // Act
        vm.prank(memberAddress);
        challengeManager.registerInputNotRevealed(setup.acceptPeginTxid, setup.inputNotRevealedSPV);

        // Assert
        streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.OP_SELECTED), "PegStatus should be OP_SELECTED");

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
            "Slot state should be ADVANCED"
        );

        // getChallengeInfo will revert if challengeTxid is not set
        vm.expectRevert(abi.encodeWithSelector(IChallengeManager.NoChallengeRegistered.selector, setup.acceptPeginTxid));
        ChallengeInfo memory challengeInfo = challengeManager.getChallengeInfo(setup.acceptPeginTxid);
    }

    function test_registerInputNotRevealed_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        pauseContracts();
        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(memberAddress);
        challengeManager.registerInputNotRevealed(setup.acceptPeginTxid, setup.inputNotRevealedSPV);
    }

    function test_registerInputNotRevealed_Revert_PeginNotRequested() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        bytes32 wrongAcceptPeginTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegBase.PeginNotRequested.selector, wrongAcceptPeginTxid));

        // Act
        vm.prank(memberAddress);
        challengeManager.registerInputNotRevealed(wrongAcceptPeginTxid, setup.inputNotRevealedSPV);
    }

    function test_registerInputNotRevealed_Revert_InvalidPegStatus() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        // Set peg status to COMPLETED to trigger invalid status error
        vm.prank(address(challengeManager));
        streamManager.setPegStatus(setup.acceptPeginTxid, PegStatus.COMPLETED);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegBase.InvalidPegStatus.selector, PegStatus.COMPLETED));

        // Act
        vm.prank(memberAddress);
        challengeManager.registerInputNotRevealed(setup.acceptPeginTxid, setup.inputNotRevealedSPV);
    }

    function test_registerInputNotRevealed_Revert_ChallengeTxidNotMatch() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        bytes32 txid = bitcoinManager.getBtcTxid(setup.challengeSPV.btcTx);
        bytes32 wrongTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        uint128 committeeId = streamManager.getCommitteeId(uint64(DEFAULT_STREAM), setup.packetNumber);

        CompactPubKey[] memory disputePubKeys = registry.getCommitteeDisputeKeys(committeeId);
        BtcTxSPVProof memory wrongSPV = createBtcTxSPVProof(createInputNotRevealedTx(wrongTxid, disputePubKeys));
        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IChallengeManager.ChallengeTxidNotMatch.selector, wrongTxid, txid));

        // Act
        vm.prank(memberAddress);
        challengeManager.registerInputNotRevealed(setup.acceptPeginTxid, wrongSPV);
    }

    function test_registerInputNotRevealed_Revert_MemberNotInCommittee() external {
        // Arrange
        (, RegisterUserTakeSetup memory setup) = setup_challenge();

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberNotInCommittee.selector, COMMITTEE_ID_STREAM_1_COMMITTEE_1, address(this)
            )
        );

        // Act
        challengeManager.registerInputNotRevealed(setup.acceptPeginTxid, setup.inputNotRevealedSPV);
    }

    function test_registerInputNotRevealed_Revert_InvalidInputNotRevealedOutputCount() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        uint128 committeeId = streamManager.getCommitteeId(uint64(DEFAULT_STREAM), setup.packetNumber);
        uint256 expectedOutputCount = registry.getCommitteeMembersLength(committeeId);
        BtcTxOut[] memory wrongOutputCount = new BtcTxOut[](0);
        setup.inputNotRevealedSPV.btcTx.outputs = wrongOutputCount;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IChallengeManager.InvalidInputNotRevealedOutputCount.selector, 0, expectedOutputCount
            )
        );

        // Act
        vm.prank(memberAddress);
        challengeManager.registerInputNotRevealed(setup.acceptPeginTxid, setup.inputNotRevealedSPV);
    }

    function test_registerInputNotRevealed_Revert_InvalidChallengeInputCount() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        BtcTxIn[] memory modifiedInputs = new BtcTxIn[](setup.inputNotRevealedSPV.btcTx.inputs.length + 1);
        for (uint256 i = 0; i < setup.inputNotRevealedSPV.btcTx.inputs.length; i++) {
            modifiedInputs[i] = setup.inputNotRevealedSPV.btcTx.inputs[i];
        }
        modifiedInputs[modifiedInputs.length - 1] = BtcTxIn({
            txId: 0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd,
            vout: 0,
            sequence: 4294967295,
            scriptSig: hex""
        });
        setup.inputNotRevealedSPV.btcTx.inputs = modifiedInputs;
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IChallengeManager.InvalidInputNotRevealedInputCount.selector,
                Constants.INPUT_NOT_REVEALED_INPUT_COUNT + 1,
                Constants.INPUT_NOT_REVEALED_INPUT_COUNT
            )
        );

        // Act
        vm.prank(memberAddress);
        challengeManager.registerInputNotRevealed(setup.acceptPeginTxid, setup.inputNotRevealedSPV);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IChallengeManager.InvalidInputNotRevealedInputCount.selector,
                Constants.INPUT_NOT_REVEALED_INPUT_COUNT + 1,
                Constants.INPUT_NOT_REVEALED_INPUT_COUNT
            )
        );

        // Act
        vm.prank(memberAddress);
        challengeManager.registerInputNotRevealed(setup.acceptPeginTxid, setup.inputNotRevealedSPV);
    }

    function test_registerStopOperatorWon_Success_MemberCall() external {
        // Arrange
        pauseAndUnpauseContracts();
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_inputRevealed();
        bytes32 txid = bitcoinManager.getBtcTxid(setup.stopOperatorWonSPV.btcTx);
        StreamPosition memory streamInfo = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.REVEALED
        });

        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        vm.expectEmit(address(challengeManager));
        emit IChallengeManager.StopOperatorWonRegistered(
            txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
        );

        // Act
        vm.prank(memberAddress);
        challengeManager.registerStopOperatorWon(setup.acceptPeginTxid, setup.stopOperatorWonSPV);

        // Assert
        streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.OP_SELECTED), "PegStatus should be OP_SELECTED");

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
            "Slot state should be ADVANCED"
        );

        // getChallengeInfo will revert if challengeTxid is not set
        vm.expectRevert(abi.encodeWithSelector(IChallengeManager.NoChallengeRegistered.selector, setup.acceptPeginTxid));
        ChallengeInfo memory challengeInfo = challengeManager.getChallengeInfo(setup.acceptPeginTxid);
    }

    function test_registerStopOperatorWon_Revert_MemberNotInCommittee() external {
        // Arrange
        pauseAndUnpauseContracts();
        (, RegisterUserTakeSetup memory setup) = setup_inputRevealed();

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ICommitteeRegistry.MemberNotInCommittee.selector, COMMITTEE_ID_STREAM_1_COMMITTEE_1, address(this)
            )
        );

        // Act
        challengeManager.registerStopOperatorWon(setup.acceptPeginTxid, setup.stopOperatorWonSPV);
    }

    function test_registerStopOperatorWon_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_inputRevealed();
        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");
        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(memberAddress);
        challengeManager.registerStopOperatorWon(setup.acceptPeginTxid, setup.stopOperatorWonSPV);
    }

    function test_registerStopOperatorWon_Revert_PeginNotRequested() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_inputRevealed();
        bytes32 wrongAcceptPeginTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegBase.PeginNotRequested.selector, wrongAcceptPeginTxid));

        // Act
        vm.prank(memberAddress);
        challengeManager.registerStopOperatorWon(wrongAcceptPeginTxid, setup.stopOperatorWonSPV);
    }

    function test_registerStopOperatorWon_Revert_InvalidPegStatus() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_inputRevealed();
        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        // Set peg status to COMPLETED to trigger invalid status error
        vm.prank(address(challengeManager));
        streamManager.setPegStatus(setup.acceptPeginTxid, PegStatus.COMPLETED);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegBase.InvalidPegStatus.selector, PegStatus.COMPLETED));

        // Act
        vm.prank(memberAddress);
        challengeManager.registerStopOperatorWon(setup.acceptPeginTxid, setup.stopOperatorWonSPV);
    }

    function test_registerStopOperatorWon_Revert_RevealTxidNotMatch() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_inputRevealed();
        bytes32 revealTxid = bitcoinManager.getBtcTxid(setup.inputRevealedSPV.btcTx);
        bytes32 wrongTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        uint128 committeeId = streamManager.getCommitteeId(uint64(DEFAULT_STREAM), setup.packetNumber);
        bytes memory committeePubKey = registry.getCommitteeTakePubKey(committeeId);
        BtcTxSPVProof memory wrongSPV = createBtcTxSPVProof(createStopOperatorWonTx(wrongTxid));
        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IChallengeManager.RevealTxidNotMatch.selector, wrongTxid, SECOND_REVEAL_TXID, revealTxid
            )
        );

        // Act
        vm.prank(memberAddress);
        challengeManager.registerStopOperatorWon(setup.acceptPeginTxid, wrongSPV);
    }

    function test_registerStopOperatorWon_Revert_InvalidStopOperatorWonTxid() external {
        // It tries to register Operator Won because input txid matches reveal TXid but it's rejected because it consumes accept pegin txid.
        // So it's not possible to be a `STOP_OPERATOR_WON` case.
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_inputRevealed();
        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IChallengeManager.InvalidStopOperatorWonTxid.selector, setup.acceptPeginTxid)
        );

        // Act
        vm.prank(memberAddress);
        challengeManager.registerStopOperatorWon(setup.acceptPeginTxid, setup.operatorWonSPV);
    }
}
