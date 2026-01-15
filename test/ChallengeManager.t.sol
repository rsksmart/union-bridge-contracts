// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {ChallengeManager} from "src/ChallengeManager.sol";
import {BtcTxSPVProof, StreamPosition} from "src/interfaces/IPegCommonTypes.sol";
import {PegStatus} from "src/interfaces/IPegCommonTypes.sol";
import {IChallengeManager} from "src/interfaces/IChallengeManager.sol";
import {IPegManagerBase} from "src/interfaces/IPegManagerBase.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IBitcoinManager} from "src/interfaces/IBitcoinManager.sol";
import {IRbtcBridge} from "src/interfaces/IRbtcBridge.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Pausable} from "src/Pausable.sol";
import {PegoutTempInfo} from "src/interfaces/IPegoutManager.sol";
import {SlotState} from "src/interfaces/IStreamManager.sol";

contract TestChallengeManager is Test, HelperContract {
    function setUp() external {
        runTestDeployScript();
    }

    // function test_registerChallenge_Success_OperatorCall() external {
    //     // Arrange
    //     pauseAndUnpauseContracts();
    //     (address opAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
    //     bytes32 txid = bitcoinManager.getBtcTxid(setup.challengeSPV.btcTx);
    //     StreamPosition memory streamInfo = StreamPosition({
    //         streamId: setup.stream.streamId,
    //         packetNumber: setup.packetNumber,
    //         slotId: setup.slotId,
    //         pegStatus: PegStatus.KICKOFF
    //     });

    //     vm.expectEmit(address(challengeManager));
    //     emit IChallengeManager.ChallengeRegistered(
    //         txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
    //     );

    //     // Act
    //     vm.prank(opAddress);
    //     challengeManager.registerChallenge(setup.acceptPeginTxid, setup.challengeSPV);

    //     streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
    //     assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.CHALLENGE));
    //     assertTrue(
    //         streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
    //         "Slot state should be ADVANCED"
    //     );
    //     PegoutTempInfo memory pegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);
    //     assertEq(pegoutInfo.challengeTxid, txid, "Challenge txid should be recorded");
    // }

    // function test_registerChallenge_Success_MemberCall() external {
    //     // Arrange
    //     pauseAndUnpauseContracts();
    //     (address opAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
    //     bytes32 txid = bitcoinManager.getBtcTxid(setup.challengeSPV.btcTx);
    //     StreamPosition memory streamInfo = StreamPosition({
    //         streamId: setup.stream.streamId,
    //         packetNumber: setup.packetNumber,
    //         slotId: setup.slotId,
    //         pegStatus: PegStatus.KICKOFF
    //     });

    //     address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
    //     assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

    //     vm.expectEmit(address(challengeManager));
    //     emit IChallengeManager.ChallengeRegistered(
    //         txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
    //     );

    //     // Act
    //     vm.prank(memberAddress);
    //     challengeManager.registerChallenge(setup.acceptPeginTxid, setup.challengeSPV);

    //     streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
    //     assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.CHALLENGE));
    //     assertTrue(
    //         streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
    //         "Slot state should be ADVANCED"
    //     );
    //     PegoutTempInfo memory pegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);
    //     assertEq(pegoutInfo.challengeTxid, txid, "Challenge txid should be recorded");
    // }

    // function test_registerChallenge_Revert_EnforcedPause_PausedContract() external {
    //     // Arrange
    //     (, RegisterUserTakeSetup memory setup) = setup_operatorTake();
    //     pauseContracts();

    //     // Assert
    //     vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

    //     // Act
    //     pegoutManager.registerChallenge(setup.acceptPeginTxid, setup.challengeSPV);
    // }

    // function test_registerChallenge_Revert_PeginNotRequested() external {
    //     // Arrange
    //     (, RegisterUserTakeSetup memory setup) = setup_operatorTake();
    //     bytes32 wrongAcceptPeginTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

    //     // Assert
    //     vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.PeginNotRequested.selector, wrongAcceptPeginTxid));

    //     // Act
    //     pegoutManager.registerChallenge(wrongAcceptPeginTxid, setup.challengeSPV);
    // }

    // function test_registerChallenge_Revert_InvalidPegStatus() external {
    //     // Arrange
    //     (, RegisterUserTakeSetup memory setup) = setup_operatorTake();

    //     // Set peg status to COMPLETED to trigger invalid status error
    //     vm.prank(address(pegoutManager));
    //     streamManager.setPegStatus(setup.acceptPeginTxid, PegStatus.COMPLETED);

    //     // Assert
    //     vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.InvalidPegStatus.selector, PegStatus.COMPLETED));

    //     // Act
    //     pegoutManager.registerChallenge(setup.acceptPeginTxid, setup.challengeSPV);
    // }

    // function test_registerChallenge_Revert_ReimbursementKickoffTxidNotMatch() external {
    //     // Arrange
    //     (address opAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
    //     bytes32 txid = bitcoinManager.getBtcTxid(setup.reimbursementKickoffSPV.btcTx);
    //     bytes32 wrongTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    //     bytes memory committeePubKey = streamManager.getCommitteePubKey(uint64(DEFAULT_STREAM), setup.packetNumber);
    //     BtcTxSPVProof memory wrongSPV = createBtcTxSPVProof(createChallengeTx(wrongTxid, committeePubKey));
    //     address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);

    //     assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

    //     // Assert
    //     vm.expectRevert(
    //         abi.encodeWithSelector(IPegoutManager.ReimbursementKickoffTxidNotMatch.selector, wrongTxid, txid)
    //     );

    //     // Act
    //     vm.prank(memberAddress);
    //     pegoutManager.registerChallenge(setup.acceptPeginTxid, wrongSPV);
    // }

    // function test_registerChallenge_Revert_MemberNotInCommittee() external {
    //     // Arrange
    //     (, RegisterUserTakeSetup memory setup) = setup_operatorTake();

    //     // Assert
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             ICommitteeRegistry.MemberNotInCommittee.selector, COMMITTEE_ID_STREAM_1_COMMITTEE_1, address(this)
    //         )
    //     );

    //     // Act
    //     pegoutManager.registerChallenge(setup.acceptPeginTxid, setup.challengeSPV);
    // }

    // function test_registerInputRevealed_Success_OperatorCall() external {
    //     // Arrange
    //     pauseAndUnpauseContracts();
    //     (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
    //     bytes32 txid = bitcoinManager.getBtcTxid(setup.inputRevealedSPV.btcTx);
    //     StreamPosition memory streamInfo = StreamPosition({
    //         streamId: setup.stream.streamId,
    //         packetNumber: setup.packetNumber,
    //         slotId: setup.slotId,
    //         pegStatus: PegStatus.CHALLENGE
    //     });

    //     vm.expectEmit(address(pegoutManager));
    //     emit IPegoutManager.RevealRegistered(txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo);

    //     // Act
    //     vm.prank(opAddress);
    //     pegoutManager.registerInputRevealed(setup.acceptPeginTxid, setup.inputRevealedSPV);

    //     streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
    //     assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.REVEALED));

    //     assertTrue(
    //         streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
    //         "Slot state should be ADVANCED"
    //     );

    //     PegoutTempInfo memory pegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);
    //     assertEq(pegoutInfo.revealTxid, txid, "Input revealed txid should be recorded");
    // }

    // function test_registerInputRevealed_Success_MemberCall() external {
    //     // Arrange
    //     pauseAndUnpauseContracts();
    //     (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
    //     bytes32 txid = bitcoinManager.getBtcTxid(setup.inputRevealedSPV.btcTx);
    //     StreamPosition memory streamInfo = StreamPosition({
    //         streamId: setup.stream.streamId,
    //         packetNumber: setup.packetNumber,
    //         slotId: setup.slotId,
    //         pegStatus: PegStatus.CHALLENGE
    //     });

    //     address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);
    //     assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

    //     vm.expectEmit(address(challengeManager));
    //     emit IChallengeManager.RevealRegistered(
    //         txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
    //     );

    //     // Act
    //     vm.prank(memberAddress);
    //     pegoutManager.registerInputRevealed(setup.acceptPeginTxid, setup.inputRevealedSPV);

    //     streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
    //     assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.REVEALED));

    //     assertTrue(
    //         streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
    //         "Slot state should be ADVANCED"
    //     );

    //     PegoutTempInfo memory pegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);
    //     assertEq(pegoutInfo.revealTxid, txid, "Input revealed txid should be recorded");
    // }

    // function test_registerInputRevealed_Revert_EnforcedPause_PausedContract() external {
    //     // Arrange
    //     (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
    //     pauseContracts();

    //     // Assert
    //     vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

    //     // Act
    //     vm.prank(opAddress);
    //     pegoutManager.registerInputRevealed(setup.acceptPeginTxid, setup.inputRevealedSPV);
    // }

    // function test_registerInputRevealed_Revert_PeginNotRequested() external {
    //     // Arrange
    //     (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
    //     bytes32 wrongAcceptPeginTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

    //     // Assert
    //     vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.PeginNotRequested.selector, wrongAcceptPeginTxid));

    //     // Act
    //     vm.prank(opAddress);
    //     pegoutManager.registerInputRevealed(wrongAcceptPeginTxid, setup.inputRevealedSPV);
    // }

    // function test_registerInputRevealed_Revert_InvalidPegStatus() external {
    //     // Arrange
    //     (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();

    //     // Set peg status to COMPLETED to trigger invalid status error
    //     vm.prank(address(pegoutManager));
    //     streamManager.setPegStatus(setup.acceptPeginTxid, PegStatus.COMPLETED);

    //     // Assert
    //     vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.InvalidPegStatus.selector, PegStatus.COMPLETED));

    //     // Act
    //     vm.prank(opAddress);
    //     pegoutManager.registerInputRevealed(setup.acceptPeginTxid, setup.inputRevealedSPV);
    // }

    // function test_registerInputRevealed_Revert_ChallengeTxidNotMatch() external {
    //     // Arrange
    //     (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
    //     bytes32 txid = bitcoinManager.getBtcTxid(setup.challengeSPV.btcTx);
    //     bytes32 wrongTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    //     bytes memory committeePubKey = streamManager.getCommitteePubKey(uint64(DEFAULT_STREAM), setup.packetNumber);
    //     BtcTxSPVProof memory wrongSPV = createBtcTxSPVProof(createRevealTx(wrongTxid, committeePubKey));

    //     // Assert
    //     vm.expectRevert(abi.encodeWithSelector(IChallengeManager.ChallengeTxidNotMatch.selector, wrongTxid, txid));

    //     // Act
    //     vm.prank(opAddress);
    //     pegoutManager.registerInputRevealed(setup.acceptPeginTxid, wrongSPV);
    // }
}
