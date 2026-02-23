// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {BtcTransaction, BtcTxSPVProof, StreamPosition, PegStatus} from "src/interfaces/IPegCommonTypes.sol";
import {BitcoinSignatureData, BtcTxIn} from "src/interfaces/IBitcoinManager.sol";
import {IPegoutManager, PegoutManagerSettings, PegoutTempInfo, PegoutRequest} from "src/interfaces/IPegoutManager.sol";
import {Slot, SlotState, SlotLocation, Stream, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {ISignatureManager} from "src/interfaces/ISignatureManager.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {Constants} from "src/libraries/Constants.sol";
import {BtcScriptParser} from "src/libraries/BtcScriptParser.sol";
import {Committee, ICommitteeRegistry, CommitteeMember} from "src/interfaces/ICommitteeRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IRbtcBridge} from "src/interfaces/IRbtcBridge.sol";
import {IPegBase} from "src/interfaces/IPegBase.sol";
import {PegManagerSettingsConfig} from "script/helpers/PegManagerSettingsConfig.sol";
import {BytesHelper} from "src/libraries/BytesHelper.sol";
import {IAccessManager} from "src/interfaces/IAccessManager.sol";

contract PegoutManagerTest is Test, HelperContract {
    // Arrange
    // https://www.blockchain.com/explorer/blocks/btc/879500
    uint64 internal constant PACKET_NUMBER = 0;
    address internal constant RSK_DESTINATION_ADDRESS = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
    Committee internal setupExpectedCommittee;

    function setUp() external {
        runTestDeployScript();
        (, Committee memory expectedCommittee,) = setup_completeCommitteeAndNewMembers();

        setupExpectedCommittee.aggregatedKey = expectedCommittee.aggregatedKey;
        setupExpectedCommittee.leaderAddress = expectedCommittee.leaderAddress;
        for (uint64 i = 0; i < expectedCommittee.members.length; i++) {
            setupExpectedCommittee.members.push(expectedCommittee.members[i]);
        }
    }

    // ============ Initialization Tests ============

    function test_initialize_Success() external {
        // Arrenge
        PegoutManagerSettings memory settings = PegManagerSettingsConfig.getSettings(block.chainid, true);

        // Assert - verify initialization state
        assertEq(pegoutManager.owner(), getDeployerAddress(), "Owner should be set"); // Owner should be set
        assertEq(pegoutManager.pauser(), address(accessManager), "Pauser should be set to accessManager"); // Pauser should be set to accessManager
        assertEq(address(pegoutManager.committeeRegistry()), address(registry), "Committee registry should be set");
        assertEq(address(pegoutManager.bitcoinManager()), address(bitcoinManager), "Bitcoin manager should be set");
        assertEq(address(pegoutManager.rbtcBridge()), address(rbtcBridge), "Rbtc bridge should be set");
        assertEq(address(pegoutManager.streamManager()), address(streamManager), "Stream manager should be set");
        assertEq(
            address(pegoutManager.signatureManager()), address(signatureManager), "Signature manager should be set"
        );
        assertEq(address(pegoutManager.rbtcBridge()), address(rbtcBridge), "Rbtc bridge should be set");
        assertEq(pegoutManager.userTakeTimeout(), settings.userTakeTimeout, "User take timeout should be set");
        assertEq(
            pegoutManager.operatorTakeTimeout(), settings.operatorTakeTimeout, "Operator take timeout should be set"
        );
    }

    function test_tryPegout_Success() external {
        pauseAndUnpauseContracts();

        // Arrange
        (BitcoinSignatureData memory expectedSignatureData, bytes32 acceptPeginTxid) = getExpectedBitcoinSignatureData();

        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        bytes memory scriptPubKey = ACCEPT_PEGIN_P2TR_SCRIPT_PUBKEY;
        uint64 amount = VALUE;
        uint64 acceptPeginAmount = amount - Constants.P2TR_FEE - Constants.SPEED_UP_AMOUNT;
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);
        uint64 packetNumber = 0;
        uint64 slotId = 0;
        Stream memory stream = streamManager.getStream(amount);

        streamManager.setSlotHarness(
            stream.streamId, packetNumber, scriptPubKey, acceptPeginTxid, acceptPeginAmount, SlotState.FILLED
        );

        // Set up mock to allow burning this amount
        bridgeMock.setWeisTransferredToUnionBridge(amountInWei);

        // Assert
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutRequested(
            userPubKey,
            COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            expectedSignatureData,
            stream.streamId,
            packetNumber,
            slotId,
            amount
        );

        // Act
        uint256 createdAt = block.timestamp;
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);

        // Assert pegout signature hash matches expected
        assertEq(
            pegoutManager.getPegoutTxid(stream.streamId, packetNumber, slotId),
            expectedSignatureData.txid,
            "expected hash doesn't match the pegout computed one"
        );

        // Assert slot was locked
        assertEq(
            uint64(streamManager.getSlot(stream.streamId, packetNumber, slotId).state),
            uint64(SlotState.LOCKED),
            "Slot was not locked"
        );

        // Assert signatures struct was initialized (expect false since not signed yet)
        assertEq(
            signatureManager.checkAllSignaturesReady(expectedSignatureData.txid),
            false,
            "Signatures struct hasn't been initialized"
        );

        _assertPegoutTempInfoCreated(acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, createdAt, userPubKey);
    }

    function _assertPegoutTempInfoCreated(
        bytes32 acceptPeginTxid,
        uint128 committeeId,
        uint256 createdAt,
        bytes memory userPubKey
    ) internal {
        PegoutTempInfo memory pegoutInfo = pegoutManager.getPegoutTempInfo(acceptPeginTxid);
        assertTrue(BytesHelper.compare(pegoutInfo.userPubKey, userPubKey), "User public key should match");
        assertEq(pegoutInfo.createdAt, createdAt, "Created at should match");
        assertEq(pegoutInfo.committeeId, committeeId, "Committee ID should match");
        assertEq(pegoutInfo.operatorTakeUpdatedAt, 0, "Operator take updated at should be zero");
        assertEq(pegoutInfo.operatorTakeAddress, address(0), "Take operator address should be zero");
        assertEq(pegoutInfo.operatorDisputePubKey, bytes32(0), "Operator dispute public key should be zero");
        assertEq(pegoutInfo.pegoutId, 0, "Pegout ID should be zero");
        assertEq(pegoutInfo.advanceFundsBlockNumber, 0, "Advance funds block number should be zero");
        assertEq(pegoutInfo.reimbursementKickoffTxid, bytes32(0), "Reimbursement kickoff txid should be zero");
    }

    function test_tryPegout_fromAcceptPegin_Success() external {
        // Setup
        uint128 committeeId = COMMITTEE_ID_STREAM_1_COMMITTEE_1;
        (bytes32 acceptPeginTxid,,) = setup_requestAndAcceptPeginFlow(committeeId);

        // Arrange
        (BitcoinSignatureData memory expectedSignatureData, bytes32 expecteAcceptPeginTxid) =
            getExpectedBitcoinSignatureData();
        assertEq(acceptPeginTxid, expecteAcceptPeginTxid, "Accept pegin txid should match expected");

        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = VALUE;
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = streamManager.getStream(amount);
        SlotLocation memory slotLocation = streamManager.getNextPegoutSlotLocation(stream.streamId);
        uint64 packetNumber = slotLocation.packetId;
        uint64 slotId = slotLocation.slotId;

        // Set up mock to allow burning this amount
        bridgeMock.setWeisTransferredToUnionBridge(amountInWei);

        // Assert
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutRequested(
            userPubKey, committeeId, expectedSignatureData, stream.streamId, packetNumber, slotId, amount
        );

        // Act
        uint256 createdAt = block.timestamp;
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);

        // Assert pegout signature hash matches expected
        assertEq(
            pegoutManager.getPegoutTxid(stream.streamId, packetNumber, slotId),
            expectedSignatureData.txid,
            "expected hash doesn't match the pegout computed one"
        );

        // Assert slot was locked
        assertEq(
            uint64(streamManager.getSlot(stream.streamId, packetNumber, slotId).state),
            uint64(SlotState.LOCKED),
            "Slot was not locked"
        );

        // Assert signatures struct was initialized (expect false since not signed yet)
        assertEq(
            signatureManager.checkAllSignaturesReady(expectedSignatureData.txid),
            false,
            "Signatures struct hasn't been initialized"
        );

        _assertPegoutTempInfoCreated(acceptPeginTxid, committeeId, createdAt, userPubKey);
    }

    function test_tryPegout_FromNextPacket_Success() external {
        // Setup
        uint256 pegoutAmount = Constants.SLOTS_PER_PACKET + 10;
        uint256 totalSlotsToUse = Constants.SLOTS_PER_PACKET + 10;
        setup_multipleRequestAndAcceptPeginFlows(pegoutAmount);

        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = VALUE;
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);
        uint64 packetNumberExpected;
        uint64 slotIdExpected;
        Stream memory stream = streamManager.getStream(amount);

        // Set up mock to allow burning for all pegouts in this test
        bridgeMock.setWeisTransferredToUnionBridge(amountInWei * pegoutAmount);

        for (uint256 i = 0; i < pegoutAmount; i++) {
            if (i % Constants.SLOTS_PER_PACKET == 0 && i != 0) {
                // We are in a new packet, so we need to update the expected packet number
                packetNumberExpected++;
            }
            slotIdExpected = uint64(i % Constants.SLOTS_PER_PACKET);
            SlotLocation memory slotLocationToUse = streamManager.getNextPegoutSlotLocation(stream.streamId);

            // Act
            vm.prank(globalUserAddress);
            pegoutManager.tryPegout{value: amountInWei}(userPubKey);

            // Assert
            Slot memory slot = streamManager.getSlot(stream.streamId, packetNumberExpected, slotIdExpected);
            assertEq(uint64(slot.state), uint64(SlotState.LOCKED), "Slot was not locked");

            assertTrue(streamManager.hasPegoutInProcess(stream.streamId));
            assertEq(slotLocationToUse.slotId, slotIdExpected);

            // Complete the slot
            BtcTransaction memory pegoutTx = createPegoutTx(slot.acceptPeginTx, userPubKey, slot.acceptPeginAmount);
            BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);
            pegoutManager.registerUserTake(pegoutTxSPVProof);
        }

        uint256 lastUsedIndex = streamManager.getNextPegoutSlotIndex(stream.streamId) - 1;
        assertEq(totalSlotsToUse, lastUsedIndex + 1);
    }

    function test_tryPegout_Revert_InvalidCompressedPubKey() external {
        // Arrange
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b00";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.InvalidCompressedPubKey.selector, userPubKey));

        // Act
        pegoutManager.tryPegout(userPubKey);
    }

    function test_tryPegout_Revert_InvalidPublicKeyFirstByte() external {
        // Arrange
        bytes memory userPubKey = hex"04d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.InvalidCompressedPubKey.selector, userPubKey));

        // Act
        pegoutManager.tryPegout(userPubKey);
    }

    function test_tryPegout_Revert_StreamNotFoundByDenomination() external {
        // Arrange
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = 5;
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.StreamNotFoundByDenomination.selector, amount));

        // Act
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);
    }

    function test_tryPegout_Revert_NoFilledSlot() external {
        // Arrange
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = 1000000; // 0.01 BTC
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = streamManager.getStream(uint64(amount));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.NoFilledSlot.selector, stream.streamId));

        // Act
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);
    }

    function test_tryPegout_Revert_OtherPegoutInProcess() external {
        // Arrange
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        bytes32 txId1 = 0xb24858ade3e5be49ae63facb93524ddf460d0771f093525dae328b6c435516a2;
        bytes32 txId2 = 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890;
        bytes memory scriptPubKey = hex"02f519f51e435c20d38af683ea86862f4591ce8cda248077c2d9a72a76b62f32";

        uint64 amount = 1000000; // 0.01 BTC
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = streamManager.getStream(uint64(amount));
        uint64 packetNumber = 0;

        streamManager.setSlotHarness(stream.streamId, packetNumber, scriptPubKey, txId1, amount, SlotState.FILLED);
        streamManager.setSlotHarness(stream.streamId, packetNumber, scriptPubKey, txId2, amount, SlotState.FILLED);

        // Set up mock to allow burning this amount
        bridgeMock.setWeisTransferredToUnionBridge(amountInWei * 2);

        // First pegout should succeed
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);

        // Assert - Second pegout should revert with PegoutInProcess
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.PegoutInProcess.selector, stream.streamId));

        // Act - Second pegout should revert with PegoutInProcess
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);
    }

    // we only check the revert case since the success cases are being checked in the _addMemberSignaturePegout tests
    function test_checkAllSignaturesReady_Revert_PegoutRequestNotFound() external {
        // Arrange
        bytes32 pegoutTxId = 0x0000000000000000000000000000000000000000000000000000000000000001;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.TxidToSignNotFound.selector, pegoutTxId));

        // Act
        signatureManager.checkAllSignaturesReady(pegoutTxId);
    }

    function test_registerUserTake_Success() external {
        // Setup
        RegisterUserTakeSetup memory setup = setup_pegout();
        StreamPosition memory streamInfo = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.USER_TAKE
        });

        // Expect the PegoutRegistered event
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutRegistered(
            setup.pegoutTxSPVProof.blockHash,
            setup.pegoutTxid,
            setup.acceptPeginTxid,
            COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            streamInfo
        );

        // Register the peg-out transaction
        pegoutManager.registerUserTake(setup.pegoutTxSPVProof);

        // Verify the slot was marked as COMPLETED
        Slot memory updatedSlot = streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId);
        assertEq(uint256(updatedSlot.state), uint256(SlotState.COMPLETED), "Slot should be marked as COMPLETED");

        assertFalse(streamManager.hasPegoutInProcess(setup.stream.streamId));
    }

    function test_registerUserTake_Success_LastSlot() external {
        // Arrange: Complete all slots except the last one (99 slots)
        setup_multiplePegFlows(Constants.SLOTS_PER_PACKET - 1);

        // Setup the last slot (slot 99)
        RegisterUserTakeSetup memory setup = setup_pegout();

        StreamPosition memory streamInfo = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.USER_TAKE
        });

        // Verify we're on the last slot
        assertEq(setup.slotId, Constants.SLOTS_PER_PACKET - 1, "Should be the last slot");

        // Record committee member state before release (reApply defaults to true, staked moves to preStaked)
        CommitteeMember[] memory members = registry.getCommitteeMembers(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        uint256[] memory stakedBefore = new uint256[](members.length);
        for (uint256 i = 0; i < members.length; i++) {
            stakedBefore[i] = memberRegistry.getMemberStakedBalance(
                members[i].memberAddress, SETUP_PENDING_COMMITTEE_DENOMINATION, setup.packetNumber
            );
        }

        // Expect PegoutRegistered, PacketClosed, and CommitteeMembersReleased events
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutRegistered(
            setup.pegoutTxSPVProof.blockHash,
            setup.pegoutTxid,
            setup.acceptPeginTxid,
            COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            streamInfo
        );

        vm.expectEmit(address(streamManager));
        emit IStreamManager.PacketClosed(setup.stream.streamId, setup.packetNumber);

        vm.expectEmit(address(registry));
        emit ICommitteeRegistry.CommitteeMembersReleased(setup.stream.streamId, setup.packetNumber);

        // Act: Register the last slot
        pegoutManager.registerUserTake(setup.pegoutTxSPVProof);

        // Assert: Verify the slot was marked as COMPLETED
        Slot memory updatedSlot = streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId);
        assertEq(uint256(updatedSlot.state), uint256(SlotState.COMPLETED), "Slot should be marked as COMPLETED");

        // Assert: Member balances shifted (staked -> preStaked, since reApply defaults to true)
        for (uint256 i = 0; i < members.length; i++) {
            uint256 stakedAfter = memberRegistry.getMemberStakedBalance(
                members[i].memberAddress, SETUP_PENDING_COMMITTEE_DENOMINATION, setup.packetNumber
            );
            uint256 preStakedAfter =
                memberRegistry.getMemberPreStakedBalance(members[i].memberAddress, SETUP_PENDING_COMMITTEE_DENOMINATION);
            assertEq(stakedAfter, 0, "Staked balance should be zero after release");
            assertEq(preStakedAfter, stakedBefore[i], "PreStaked should equal former staked (reApply=true)");
        }
    }

    function test_registerUserTake_Revert_InvalidSlotState() external {
        RegisterUserTakeSetup memory setup = setup_pegout();

        // Override the slot state to FILLED instead of LOCKED
        streamManager.setSlotStateHarness(setup.stream.streamId, setup.packetNumber, setup.slotId, SlotState.FILLED);

        vm.expectRevert(
            abi.encodeWithSelector(IPegoutManager.InvalidSlotState.selector, SlotState.FILLED, SlotState.LOCKED)
        );

        pegoutManager.registerUserTake(setup.pegoutTxSPVProof);
    }

    function test_registerUserTake_Revert_IncorrectVout() external {
        // Setup
        RegisterUserTakeSetup memory setup = setup_pegout();

        // Override the vout to be 1 instead of 0
        setup.pegoutTx.inputs[0].vout = 1;
        setup.pegoutTxSPVProof = createBtcTxSPVProof(setup.pegoutTx);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPegoutManager.IncorrectVout.selector, uint32(1), Constants.ACCEPT_PEGIN_VOUT_TAPTREE
            )
        );

        pegoutManager.registerUserTake(setup.pegoutTxSPVProof);
    }

    function test_registerUserTake_Revert_NotEnoughConfirmations() external {
        RegisterUserTakeSetup memory setup = setup_pegout();

        // Set mock bridge confirmations to insufficient amount
        int256 actualConfirmations = 0;
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);

        vm.expectRevert(
            abi.encodeWithSelector(
                IRbtcBridge.NotEnoughConfirmations.selector, actualConfirmations, setup.stream.peginConfirmations
            )
        );

        pegoutManager.registerUserTake(setup.pegoutTxSPVProof);
    }

    function test_registerUserTake_Revert_IncorrectOutputScript() external {
        RegisterUserTakeSetup memory setup = setup_pegout();

        // Change the first output to have an incorrect script (not P2WPKH for the user's pubkey)
        setup.pegoutTx.outputs[0].scriptPubKey = hex"001499999999999999999999999999999999999999"; // Wrong script
        setup.pegoutTxSPVProof = createBtcTxSPVProof(setup.pegoutTx);

        // Calculate expected script for user's pubkey
        bytes memory expectedScript = BtcScriptParser.getP2WPKHScript(setup.userPubKey);

        // Expect revert for incorrect output script
        vm.expectRevert(
            abi.encodeWithSelector(
                IPegoutManager.IncorrectOutputScript.selector, setup.pegoutTx.outputs[0].scriptPubKey, expectedScript
            )
        );

        // Register the peg-out transaction
        pegoutManager.registerUserTake(setup.pegoutTxSPVProof);
    }

    function test_registerUserTake_Revert_AlreadyPaid() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegout();
        // Set the slot state to COMPLETED (already processed)
        streamManager.setSlotStateHarness(setup.stream.streamId, setup.packetNumber, setup.slotId, SlotState.COMPLETED);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegoutManager.InvalidSlotState.selector, SlotState.COMPLETED, SlotState.LOCKED)
        );

        // Act
        pegoutManager.registerUserTake(setup.pegoutTxSPVProof);
    }

    function test_pegoutUserTake_Success() external {
        // =========== Request Peg-In & Accept Peg-In ============
        (bytes32 acceptPeginTxid, BtcTransaction memory requestPeginTx, BtcTransaction memory acceptPeginTx) =
            setup_requestAndAcceptPeginFlow(COMMITTEE_ID_STREAM_1_COMMITTEE_1);

        // =================== Request Peg-Out ===================
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        uint64 pegoutAmount = VALUE; // Same amount as peg-in
        uint256 pegoutAmountInWei = BtcHelper.satoshiToWei(pegoutAmount);

        // Calculate expected values
        Stream memory stream = streamManager.getStream(pegoutAmount);
        SlotLocation memory slotLocation = streamManager.getNextPegoutSlotLocation(stream.streamId);

        // Set up BridgeMock to allow burning this amount
        bridgeMock.setWeisTransferredToUnionBridge(pegoutAmountInWei);

        // Request peg-out
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: pegoutAmountInWei}(userPubKey);

        // Verify slot was locked
        Slot memory slot = streamManager.getSlot(stream.streamId, slotLocation.packetId, slotLocation.slotId);
        assertEq(uint256(slot.state), uint256(SlotState.LOCKED), "Slot should be locked after peg-out request");
        assertEq(slot.acceptPeginTx, acceptPeginTxid, "Slot should reference the correct accept peg-in tx");

        // =================== Register Peg-Out ===================
        BtcTransaction memory pegoutTx = createPegoutTx(acceptPeginTxid, userPubKey, slot.acceptPeginAmount);
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);

        // Calculate expected transaction id
        bytes32 expectedPegoutTxid = bitcoinManager.getBtcTxid(pegoutTx);

        // Expect the PegoutRegistered event
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutRegistered(
            pegoutTxSPVProof.blockHash,
            expectedPegoutTxid,
            acceptPeginTxid,
            COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            StreamPosition({
                streamId: stream.streamId,
                packetNumber: slotLocation.packetId,
                slotId: slotLocation.slotId,
                pegStatus: PegStatus.USER_TAKE
            })
        );

        // Register peg-out transaction
        pegoutManager.registerUserTake(pegoutTxSPVProof);

        // Validate the full peg-out flow, avoiding stack too deep error
        _validateFullPegoutFlow(
            requestPeginTx, acceptPeginTxid, stream, slotLocation.packetId, slotLocation.slotId, userPubKey
        );
    }

    function _validateFullPegoutFlow(
        BtcTransaction memory requestPeginTx,
        bytes32 acceptPeginTxid,
        Stream memory stream,
        uint64 expectedPacketNumber,
        uint64 expectedSlotId,
        bytes memory userPubKey
    ) internal view {
        // slot should be COMPLETED
        Slot memory finalSlot = streamManager.getSlot(stream.streamId, expectedPacketNumber, expectedSlotId);
        assertEq(
            uint256(finalSlot.state),
            uint256(SlotState.COMPLETED),
            "Slot should be marked as COMPLETED after peg-out registration"
        );

        bytes32 requestPeginTxid = bitcoinManager.getBtcTxid(requestPeginTx);
        PegoutTempInfo memory pegoutInfo = pegoutManager.getPegoutTempInfo(acceptPeginTxid);
        StreamPosition memory streamPosition = peginManager.getStreamPositionByRequestPegin(requestPeginTxid);

        // internal state should be consistent
        assertEq(uint256(streamPosition.pegStatus), uint256(PegStatus.COMPLETED), "Peg status should be COMPLETED");
        assertEq(pegoutInfo.userPubKey, userPubKey, "User public key should match");
        assertEq(streamPosition.streamId, stream.streamId, "Stream ID should match");
        assertEq(streamPosition.packetNumber, expectedPacketNumber, "Packet number should match");
        assertEq(streamPosition.slotId, expectedSlotId, "Slot ID should match");
        assertEq(peginManager.getAcceptPegin(requestPeginTxid), acceptPeginTxid, "Accept peg-in tx id should match");
        assertTrue(
            streamManager.getSlot(stream.streamId, expectedPacketNumber, expectedSlotId).state == SlotState.COMPLETED,
            "Slot state should be COMPLETED"
        );
    }

    function test_triggerOperatorTake_Revert_UserTakeAlreadySigned() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegoutAndMemberNonces();
        setup_addMemberSignature_MultipleMembers(setup.pegoutTxid, 0, registry.committeeMemberCount());

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.UserTakeAlreadySigned.selector, setup.pegoutTxid));

        // Act
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);
    }

    function test_triggerOperatorTake_Revert_PeginNotFoundForPegout() external {
        // Arrange
        bytes32 pegoutTxid = hex"0001";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.PeginNotFoundForPegout.selector, pegoutTxid));

        // Act
        pegoutManager.triggerOperatorTake(pegoutTxid);
    }

    function test_triggerOperatorTake_Revert_UserTakeTimeoutNotExpired() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegoutAndMemberNonces();
        uint256 createdAt = block.timestamp;
        uint256 expireAt = createdAt + TAKE_0_TIMEOUT_DEFAULT;
        setup_addMemberSignature_MultipleMembers(setup.pegoutTxid, 0, registry.committeeMemberCount() - 1);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.UserTakeTimeoutNotExpired.selector, createdAt, expireAt));

        // Act
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);

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

        uint256 previousSequenceNumber = pegoutManager.sequenceNumber();

        // Assert event
        assertEventOperatorTakeTriggered(setup, expectedOperatorAddress, createdAt);

        // Act
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);

        // Assert status
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );

        assertEq(pegoutManager.sequenceNumber(), previousSequenceNumber + 1, "Sequence number should be incremented");
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

        uint256 previousSequenceNumber = pegoutManager.sequenceNumber();

        // Assert
        // By implementation, first operator is skipped.
        assertEventOperatorTakeTriggered(setup, secondOpAddress, createdAt);

        // Act
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);

        // Assert status
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );

        assertEq(pegoutManager.sequenceNumber(), previousSequenceNumber + 1, "Sequence number should be incremented");
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
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);
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
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);
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
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);
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
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);
    }

    function test_triggerOperatorTake_Revert_OperatorTakeTimeoutNotExpired() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegoutAndMemberNonces();
        setup_addMemberSignature_MultipleMembers(setup.pegoutTxid, 0, registry.committeeMemberCount() - 1);
        vm.warp(block.timestamp + TAKE_0_TIMEOUT_DEFAULT + 1);
        // First call to triggerOperatorTake should set the status to TAKE_1
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IPegoutManager.OperatorTakeTimeoutNotExpired.selector,
                block.timestamp,
                block.timestamp + TAKE_1_TIMEOUT_DEFAULT
            )
        );

        // Act
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);

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
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);
        // Expire TAKE_1
        vm.warp(block.timestamp + TAKE_1_TIMEOUT_DEFAULT + 1);
        // Get the last operator take index
        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        uint256 lastOpTakeIndex = committee.operatorTakeIndex;
        uint256 expectedOpTakeIndex = (lastOpTakeIndex + 1) % committee.members.length;
        uint256 previousSequenceNumber = pegoutManager.sequenceNumber();

        // Assert
        address expectedOperator = committee.members[expectedOpTakeIndex].memberAddress;
        assertEventOperatorTakeTriggered(setup, expectedOperator, createdAt);

        // Act
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);

        // Assert status
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );
        assertEq(pegoutManager.sequenceNumber(), previousSequenceNumber + 1, "Sequence number should be incremented");
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
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);
        // Expire TAKE_1
        vm.warp(block.timestamp + TAKE_1_TIMEOUT_DEFAULT + 1);

        // Assert
        // This call will select the third operator
        assertEventOperatorTakeTriggered(setup, thirdOpAddress, createdAt);

        // Act
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);

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
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);

        for (uint256 i = 0; i < operatorsCount - 1; i++) {
            vm.warp(block.timestamp + TAKE_1_TIMEOUT_DEFAULT + 1);
            pegoutManager.triggerOperatorTake(setup.pegoutTxid);
        }

        vm.warp(block.timestamp + TAKE_1_TIMEOUT_DEFAULT + 1);
        return setup.pegoutSignatureHash;
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
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutRegistered(
            setup.operatorTakeSPV.blockHash,
            operatorTakeTxid,
            setup.acceptPeginTxid,
            COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            streamInfo
        );

        // Act
        vm.prank(operatorAddress);
        pegoutManager.registerOperatorTake(setup.operatorTakeSPV);

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
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutRegistered(
            setup.operatorTakeSPV.blockHash, txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
        );

        vm.expectEmit(address(streamManager));
        emit IStreamManager.PacketClosed(setup.stream.streamId, setup.packetNumber);

        // Act: Register the operator take for the last slot
        vm.prank(operatorAddress);
        pegoutManager.registerOperatorTake(setup.operatorTakeSPV);

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
        pegoutManager.registerOperatorTake(operatorTakeSPV);

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
        pegoutManager.registerOperatorTake(setup.operatorTakeSPV);
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
        pegoutManager.registerOperatorTake(setup.operatorTakeSPV);

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
        pegoutManager.registerOperatorTake(operatorTakeSPV);

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
            abi.encodeWithSelector(IPegoutManager.OperatorTakeAddressNotMatch.selector, operatorAddress, wrongOperator)
        );

        // Act
        vm.prank(wrongOperator);
        pegoutManager.registerOperatorTake(setup.operatorTakeSPV);

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
            abi.encodeWithSelector(IPegoutManager.OperatorTakeTxidNotMatch.selector, wrongTakeTxid, realTakeTxid)
        );

        // Act
        vm.prank(operatorAddress);
        pegoutManager.registerOperatorTake(operatorTakeSPV);

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
        pegoutManager.registerOperatorTake(setup.operatorTakeSPV);

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
        pegoutManager.registerOperatorTake(setup.operatorTakeSPV);
    }

    function test_registerOperatorTake_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseContracts();
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();

        // Act
        vm.prank(operatorAddress);
        pegoutManager.registerOperatorTake(setup.operatorTakeSPV);
    }

    function test_userTakeTimeout_Success() external view {
        // Act
        uint256 timeout = pegoutManager.userTakeTimeout();

        // Assert
        assertEq(timeout, TAKE_0_TIMEOUT_DEFAULT);
    }

    function test_operatorTakeTimeout_Success() external view {
        // Act
        uint256 timeout = pegoutManager.operatorTakeTimeout();

        // Assert
        assertEq(timeout, TAKE_1_TIMEOUT_DEFAULT);
    }

    function test_setUserTakeTimeout_Success() external {
        // Arrange
        uint256 timeout = TAKE_0_TIMEOUT_DEFAULT + 1 days;

        // Assert
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.UserTakeTimeoutUpdated(timeout);

        // Act
        vm.prank(address(pegoutManager.owner()));
        pegoutManager.setUserTakeTimeout(timeout);

        // Assert
        uint256 newTimeout = pegoutManager.userTakeTimeout();
        assertEq(newTimeout, timeout);
    }

    function test_setOperatorTakeTimeout_Success() external {
        // Arrange
        uint256 timeout = TAKE_1_TIMEOUT_DEFAULT + 1 days;

        // Assert
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.OperatorTakeTimeoutUpdated(timeout);

        // Act
        vm.prank(address(pegoutManager.owner()));
        pegoutManager.setOperatorTakeTimeout(timeout);

        // Assert
        uint256 newTimeout = pegoutManager.operatorTakeTimeout();
        assertEq(newTimeout, timeout);
    }

    function test_setUserTakeTimeout_Revert_InvalidTimeout() external {
        // Arrange
        address owner = pegoutManager.owner();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.InvalidTimeout.selector, 0));

        // Act
        vm.prank(address(owner));
        pegoutManager.setUserTakeTimeout(0);
    }

    function test_setOperatorTakeTimeout_Revert_InvalidTimeout() external {
        // Arrange
        address owner = pegoutManager.owner();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.InvalidTimeout.selector, 0));

        // Act
        vm.prank(address(owner));
        pegoutManager.setOperatorTakeTimeout(0);
    }

    function test_setUserTakeTimeout_Revert_OwnableUnauthorizedAccount() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        pegoutManager.setUserTakeTimeout(1 days);
    }

    function test_setOperatorTakeTimeout_Revert_OwnableUnauthorizedAccount() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        pegoutManager.setOperatorTakeTimeout(1 days);
    }

    function test_tryPegout_SkipBlockedSlot() external {
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        uint64 amount = VALUE;
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = streamManager.getStream(amount);
        bytes32 txId = 0xb24858ade3e5be49ae63facb93524ddf460d0771f093525dae328b6c435516a2;
        bytes memory scriptPubKey = hex"02f519f51e435c20d38af683ea86862f4591ce8cda248077c2d9a72a76b62f32";

        // 1. Setup pattern: BLOCKED, FILLED
        uint64 blockedSlotId =
            streamManager.setSlotHarness(stream.streamId, 0, scriptPubKey, txId, amount, SlotState.RESERVED);
        streamManager.setSlotStateHarness(stream.streamId, 0, blockedSlotId, SlotState.BLOCKED);
        streamManager.setSlotHarness(stream.streamId, 0, scriptPubKey, txId, amount, SlotState.FILLED);

        // Set up mock to allow burning this amount
        bridgeMock.setWeisTransferredToUnionBridge(amountInWei);

        // 2. Call tryPegout should skip blocked slot and lock filled slot
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);

        // 3. Verify FILLED slot is locked and BLOCKED slot remains unchanged
        Slot memory blockedSlot = streamManager.getSlot(stream.streamId, 0, blockedSlotId);
        assertEq(uint256(blockedSlot.state), uint256(SlotState.BLOCKED), "Blocked slot should remain BLOCKED");

        Slot memory filledSlot = streamManager.getSlot(stream.streamId, 0, 1);
        assertEq(uint256(filledSlot.state), uint256(SlotState.LOCKED), "FILLED slot should be LOCKED");
    }

    function test_tryPegout_AllSlotsBlocked() external {
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        uint64 amount = VALUE;
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = streamManager.getStream(amount);

        // 1. Fill first packet with all BLOCKED slots
        streamManager.pushSlotsHarness(stream.streamId, 0, Constants.SLOTS_PER_PACKET, SlotState.BLOCKED);

        // 2. Try to call tryPegout
        // 3. Expect NoFilledSlot revert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.NoFilledSlot.selector, stream.streamId));

        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);
    }

    function test_tryPegout_CrossPacketBlocking() external {
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        uint64 amount = VALUE;
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = streamManager.getStream(amount);
        bytes32 txId = 0xb24858ade3e5be49ae63facb93524ddf460d0771f093525dae328b6c435516a2;
        bytes memory scriptPubKey = hex"02f519f51e435c20d38af683ea86862f4591ce8cda248077c2d9a72a76b62f32";

        // 1. Fill first packet with all BLOCKED slots
        streamManager.pushSlotsHarness(stream.streamId, 0, Constants.SLOTS_PER_PACKET, SlotState.BLOCKED);

        // 2. Create second packet with the existing committee setup
        uint128 committeeId = COMMITTEE_ID_STREAM_1_COMMITTEE_1;
        bytes32[] memory disputeKeys = registry.getCommitteeDisputeKeys(committeeId);
        vm.prank(address(registry));
        streamManager.createNewPacket(stream.streamId, committeeId, setupExpectedCommittee.aggregatedKey, disputeKeys);
        streamManager.setSlotHarness(stream.streamId, 1, scriptPubKey, txId, amount, SlotState.FILLED);

        // Set up mock to allow burning this amount
        bridgeMock.setWeisTransferredToUnionBridge(amountInWei);

        // 3. Call tryPegout
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);

        // 4. Verify it skips entire first packet and locks slot in second packet
        Slot memory lockedSlot = streamManager.getSlot(stream.streamId, 1, 0);
        assertEq(uint256(lockedSlot.state), uint256(SlotState.LOCKED), "First slot in second packet should be LOCKED");
    }

    function test_tryPegout_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        uint64 amount = 1000000; // 0.01 BTC
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);
    }

    function test_registerUserTake_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegout();
        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        pegoutManager.registerUserTake(setup.pegoutTxSPVProof);
    }

    function test_registerUserTake_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseContracts();
        RegisterUserTakeSetup memory setup = setup_pegout();

        // Act
        pegoutManager.registerUserTake(setup.pegoutTxSPVProof);
    }

    function test_triggerOperatorTake_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegout();
        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        pegoutManager.triggerOperatorTake(setup.pegoutSignatureHash);
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
        assertEventOperatorTakeTriggered(setup, secondOpAddress, createdAt);

        // Act
        pegoutManager.triggerOperatorTake(pegoutTxId);
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

        PegoutTempInfo memory pegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);

        // Assert
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.AdvanceFundsRegistered(
            setup.advanceFundsSPV.blockHash,
            txid,
            setup.acceptPeginTxid,
            setup.pegoutId,
            COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            streamInfo,
            pegoutInfo.operatorTakePubKey
        );

        // Act
        vm.prank(opAddress);
        pegoutManager.registerAdvanceFunds(setup.acceptPeginTxid, setup.advanceFundsSPV);

        streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.ADVANCED));
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
            "Slot state should be ADVANCED"
        );

        PegoutTempInfo memory updatedPegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);
        assertEq(updatedPegoutInfo.operatorTakeUpdatedAt, block.timestamp, "operatorTakeUpdatedAt should be updated");
    }

    function test_registerAdvanceFunds_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_advanceFunds();
        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(opAddress);
        pegoutManager.registerAdvanceFunds(setup.acceptPeginTxid, setup.advanceFundsSPV);
    }

    function test_registerAdvanceFunds_Revert_PeginNotRequested() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_advanceFunds();
        bytes32 wrongAcceptPeginTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegBase.PeginNotRequested.selector, wrongAcceptPeginTxid));

        // Act
        vm.prank(opAddress);
        pegoutManager.registerAdvanceFunds(wrongAcceptPeginTxid, setup.advanceFundsSPV);
    }

    function test_registerAdvanceFunds_Revert_WrongUserAmount() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_advanceFunds();

        BtcTxSPVProof memory wrongSPV =
            createBtcTxSPVProof(createAdvanceFundsTx(setup.userPubKey, VALUE + 1, setup.pegoutId));

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IPegoutManager.WrongUserAmount.selector,
                setup.advanceFundsSPV.btcTx.outputs[0].amount + 1,
                setup.advanceFundsSPV.btcTx.outputs[0].amount
            )
        );

        // Act
        vm.prank(opAddress);
        pegoutManager.registerAdvanceFunds(setup.acceptPeginTxid, wrongSPV);
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
                hex"6a30e614e19d9d364861907b6c1cf3c922887be82c255cdb4f966a549c291cfde5"
            )
        );

        // Act
        vm.prank(opAddress);
        pegoutManager.registerAdvanceFunds(setup.acceptPeginTxid, wrongSPV);
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
        pegoutManager.registerAdvanceFunds(setup.acceptPeginTxid, wrongSPV);
    }

    function test_registerAdvanceFunds_Revert_OperatorTakeAddressNotMatch() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_advanceFunds();
        address wrongAddress = address(this);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegoutManager.OperatorTakeAddressNotMatch.selector, opAddress, wrongAddress)
        );

        // Act
        vm.prank(wrongAddress);
        pegoutManager.registerAdvanceFunds(setup.acceptPeginTxid, setup.advanceFundsSPV);
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
        pegoutManager.registerAdvanceFunds(setup.acceptPeginTxid, setup.advanceFundsSPV);
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

        // Get the expected pegoutId from the pegout info
        PegoutTempInfo memory pegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);
        bytes memory expectedBaseEvent = abi.encodePacked(pegoutInfo.pegoutId);

        // Assert - expect ReimbursementKickoffRegistered event
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.ReimbursementKickoffRegistered(
            txid,
            setup.acceptPeginTxid,
            pegoutInfo.pegoutId,
            COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            streamInfo,
            pegoutInfo.operatorTakePubKey
        );

        // Assert - expect BaseEventSet event from RbtcBridge
        vm.expectEmit(address(rbtcBridge));
        emit IRbtcBridge.BaseEventSet(expectedBaseEvent);

        // Act
        vm.prank(opAddress);
        pegoutManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);

        // Verify peg status was updated
        streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.KICKOFF));
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
            "Slot state should be ADVANCED"
        );
        // Get updated pegoutInfo after the call to verify reimbursementKickoffTxid was set
        PegoutTempInfo memory updatedPegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);
        assertEq(updatedPegoutInfo.reimbursementKickoffTxid, txid, "Reimbursement kickoff txid should be recorded");
        assertEq(updatedPegoutInfo.operatorTakeUpdatedAt, block.timestamp, "operatorTakeUpdatedAt should be updated");

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
        pegoutManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);
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
        pegoutManager.registerReimbursementKickoff(wrongAcceptPeginTxid, setup.reimbursementKickoffSPV);
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
        pegoutManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);
    }

    function test_registerReimbursementKickoff_Revert_InvalidSlotId() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();
        uint32 slotId = setup.reimbursementKickoffSPV.btcTx.inputs[Constants.KICKOFF_VIN_SLOT_ID].vout;
        setup.reimbursementKickoffSPV.btcTx.inputs[Constants.KICKOFF_VIN_SLOT_ID].vout += 1; // Modify the tx to break slot id check

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.InvalidSlotId.selector, slotId + 1, slotId));

        // Act
        vm.prank(opAddress);
        pegoutManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);
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
                IPegoutManager.InvalidKickoffInputCount.selector,
                Constants.KICKOFF_INPUT_COUNT + 1,
                Constants.KICKOFF_INPUT_COUNT
            )
        );

        // Act
        vm.prank(opAddress);
        pegoutManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);
    }

    function test_registerReimbursementKickoff_Success_BaseEventContainsPegoutId() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        pauseAndUnpauseContracts();
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();

        // Get the pegoutId from the pegout info before calling registerReimbursementKickoff
        PegoutTempInfo memory pegoutInfoBefore = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);
        bytes32 expectedPegoutId = pegoutInfoBefore.pegoutId;

        // Act
        vm.prank(opAddress);
        pegoutManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);

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
        pegoutManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);
    }

    function test_registerReimbursementKickoff_Success_BaseEventIs32Bytes() external {
        // Arrange
        bridgeMock.setStoreEvents(true);
        pauseAndUnpauseContracts();
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();

        // Act
        vm.prank(opAddress);
        pegoutManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);

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

        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutRegistered(
            setup.operatorWonSPV.blockHash, txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
        );

        // Act
        vm.prank(opAddress);
        pegoutManager.registerOperatorWon(setup.operatorWonSPV);

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
        pegoutManager.registerOperatorWon(setup.operatorWonSPV);
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
        pegoutManager.registerOperatorWon(wrongOperatorWonSPV);
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
        pegoutManager.registerOperatorWon(setup.operatorWonSPV);
    }

    function test_setUserTakeTimeout_Success_PausedContract() external {
        // Arrange
        pauseContracts();

        uint256 timeout = TAKE_0_TIMEOUT_DEFAULT + 1 days;
        address owner = pegoutManager.owner();

        // Assert
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.UserTakeTimeoutUpdated(timeout);

        // Act
        vm.prank(owner);
        pegoutManager.setUserTakeTimeout(timeout);
    }

    function test_setOperatorTakeTimeout_Success_PausedContract() external {
        // Arrange
        pauseContracts();

        uint256 timeout = TAKE_1_TIMEOUT_DEFAULT + 1 days;
        address owner = pegoutManager.owner();

        // Assert
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.OperatorTakeTimeoutUpdated(timeout);

        // Act
        vm.prank(owner);
        pegoutManager.setOperatorTakeTimeout(timeout);
    }

    // ============ RbtcBridge Integration Tests ============

    function test_tryPegout_RbtcBridgeIntegration() external {
        // Arrange - Setup pegin flow first so we have acceptPeginAmount to burn
        setup_requestAndAcceptPeginFlow(COMMITTEE_ID_STREAM_1_COMMITTEE_1);

        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        uint64 amount = VALUE;
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = streamManager.getStream(amount);
        SlotLocation memory slotLocation = streamManager.getNextPegoutSlotLocation(stream.streamId);
        uint64 packetNumber = slotLocation.packetId;
        uint64 slotId = slotLocation.slotId;
        Slot memory slot = streamManager.getSlot(stream.streamId, packetNumber, slotId);

        // Calculate expected burn amount (acceptPeginAmount, not msg.value)
        uint256 expectedBurnAmount = BtcHelper.satoshiToWei(slot.acceptPeginAmount);
        uint256 expectedFeeAmount = amountInWei - expectedBurnAmount;

        // Set up mock to allow burning this amount
        bridgeMock.setWeisTransferredToUnionBridge(expectedBurnAmount);

        uint256 pegoutManagerBalanceBefore = address(pegoutManager).balance;

        // Act
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);

        // Assert - verify correct amount was burned (acceptPeginAmount)
        assertEq(bridgeMock.getUnionBridgeLockingCap(), 400 ether, "Locking cap should be restored after burn");

        // Assert - verify fees stayed in PegoutManager (msg.value - amountToBurn)
        assertEq(
            address(pegoutManager).balance,
            pegoutManagerBalanceBefore + expectedFeeAmount,
            "Fees should remain in PegoutManager"
        );
    }

    function test_tryPegout_Revert_BridgeReleaseInvalidValue() external {
        // Arrange - Setup pegin flow
        setup_requestAndAcceptPeginFlow(COMMITTEE_ID_STREAM_1_COMMITTEE_1);

        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        uint64 amount = VALUE;
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = streamManager.getStream(amount);
        SlotLocation memory slotLocation = streamManager.getNextPegoutSlotLocation(stream.streamId);
        uint64 packetNumber = slotLocation.packetId;
        uint64 slotId = slotLocation.slotId;

        Slot memory slot = streamManager.getSlot(stream.streamId, packetNumber, slotId);

        uint256 burnAmount = BtcHelper.satoshiToWei(slot.acceptPeginAmount);

        // Set weisTransferred to 0 (nothing has been minted) to trigger error
        bridgeMock.setWeisTransferredToUnionBridge(0);

        // Assert - expect revert with specific error
        vm.expectRevert(abi.encodeWithSelector(IRbtcBridge.BridgeReleaseInvalidValue.selector, burnAmount));

        // Act
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);
    }

    function test_tryPegout_Revert_BridgeTransfersDisabled() external {
        // Arrange - Setup pegin flow
        setup_requestAndAcceptPeginFlow(COMMITTEE_ID_STREAM_1_COMMITTEE_1);

        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        uint64 amount = VALUE;
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = streamManager.getStream(amount);
        SlotLocation memory slotLocation = streamManager.getNextPegoutSlotLocation(stream.streamId);
        uint64 packetNumber = slotLocation.packetId;
        uint64 slotId = slotLocation.slotId;

        Slot memory slot = streamManager.getSlot(stream.streamId, packetNumber, slotId);

        uint256 burnAmount = BtcHelper.satoshiToWei(slot.acceptPeginAmount);

        // Set up mock to allow burning this amount
        bridgeMock.setWeisTransferredToUnionBridge(burnAmount);

        // Disable transfers on the bridge
        bridgeMock.setTransfersDisabled(true);

        // Assert - expect revert with specific error
        vm.expectRevert(IRbtcBridge.BridgeTransfersDisabled.selector);

        // Act
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);
    }

    function test_tryPegout_Revert_BridgeUnauthorizedCaller() external {
        // Arrange - Setup pegin flow
        setup_requestAndAcceptPeginFlow(COMMITTEE_ID_STREAM_1_COMMITTEE_1);

        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        uint64 amount = VALUE;
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = streamManager.getStream(amount);
        SlotLocation memory slotLocation = streamManager.getNextPegoutSlotLocation(stream.streamId);
        uint64 packetNumber = slotLocation.packetId;
        uint64 slotId = slotLocation.slotId;

        Slot memory slot = streamManager.getSlot(stream.streamId, packetNumber, slotId);

        uint256 burnAmount = BtcHelper.satoshiToWei(slot.acceptPeginAmount);

        // Set up mock to allow burning this amount
        bridgeMock.setWeisTransferredToUnionBridge(burnAmount);

        // Change union bridge address to trigger unauthorized caller error
        bridgeMock.setUnionBridgeContractAddressForTestnet(address(0x9999));

        // Assert - expect revert with specific error
        vm.expectRevert(IRbtcBridge.BridgeUnauthorizedCaller.selector);

        // Act
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);
    }

    function test_getPegoutTxid_Success() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_pegout();

        // Act
        bytes32 txid1 = pegoutManager.getPegoutTxid(setup.stream.streamId, setup.packetNumber, setup.slotId);
        bytes32 txid2 = pegoutManager.getPegoutTxid(setup.acceptPeginTxid);

        // Assert
        assertNotEq(txid1, bytes32(0), "Returned txid should not be zero");
        assertNotEq(txid2, bytes32(0), "Returned txid should not be zero");
        assertEq(txid1, txid2, "Both txids should match");
    }

    function test_getPegoutTxid_Revert_PegoutTxidNotFound() external {
        // Arrange
        Stream memory stream = streamManager.getStream(VALUE);
        uint64 packetNumber = 0;
        uint64 slotId = 0;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegoutManager.PegoutTxidNotFound.selector, stream.streamId, packetNumber, slotId)
        );

        // Act
        pegoutManager.getPegoutTxid(stream.streamId, packetNumber, slotId);
    }

    // ============ Operator Take Timeout Enforcement Tests ============

    function test_triggerOperatorTake_Success_FromAdvanced() external {
        // Arrange - setup_reimbursementKickoff brings state to ADVANCED
        (, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();
        PegoutTempInfo memory previousPegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);

        // Expire the operator take timeout
        vm.warp(block.timestamp + TAKE_1_TIMEOUT_DEFAULT + 1);

        // Get the expected next operator
        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        uint256 expectedOpTakeIndex = (committee.operatorTakeIndex + 1) % committee.members.length;
        address expectedOperatorAddress = committee.members[expectedOpTakeIndex].memberAddress;

        // Assert
        assertEventOperatorTakeTriggered(setup, expectedOperatorAddress, previousPegoutInfo.createdAt);

        // Act
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);

        // Assert - status should be reset to OP_SELECTED
        StreamPosition memory updatedStreamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertTrue(updatedStreamInfo.pegStatus == PegStatus.OP_SELECTED, "PegStatus should be reset to OP_SELECTED");
    }

    function test_triggerOperatorTake_Success_FromKickoff() external {
        // Arrange - setup_operatorTake brings state to KICKOFF
        (, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        PegoutTempInfo memory previousPegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);

        // Expire the operator take timeout
        vm.warp(block.timestamp + TAKE_1_TIMEOUT_DEFAULT + 1);

        // Get the expected next operator
        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        uint256 expectedOpTakeIndex = (committee.operatorTakeIndex + 1) % committee.members.length;
        address expectedOperatorAddress = committee.members[expectedOpTakeIndex].memberAddress;

        // Assert
        assertEventOperatorTakeTriggered(setup, expectedOperatorAddress, previousPegoutInfo.createdAt);

        // Act
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);

        // Assert - status should be reset to OP_SELECTED
        StreamPosition memory updatedStreamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertTrue(updatedStreamInfo.pegStatus == PegStatus.OP_SELECTED, "PegStatus should be reset to OP_SELECTED");
    }

    function test_triggerOperatorTake_FromAdvanced_Revert_OperatorTakeTimeoutNotExpired() external {
        // Arrange - setup_reimbursementKickoff brings state to ADVANCED
        (, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();

        // Get operatorTakeUpdatedAt
        PegoutTempInfo memory pegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);
        uint256 operatorTakeUpdatedAt = pegoutInfo.operatorTakeUpdatedAt;

        // Assert - should revert because timeout hasn't expired
        vm.expectRevert(
            abi.encodeWithSelector(
                IPegoutManager.OperatorTakeTimeoutNotExpired.selector,
                operatorTakeUpdatedAt,
                operatorTakeUpdatedAt + TAKE_1_TIMEOUT_DEFAULT
            )
        );
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);
    }

    function test_enqueuePegout_Revert_NoFreeFilledSlot() external {
        // Arrange
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = VALUE;
        Stream memory stream = streamManager.getStream(amount);
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);
        uint64 queueLength = 0;
        uint64 filledSlotCount = 0;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IPegoutManager.NoFreeFilledSlot.selector, stream.streamId, queueLength, filledSlotCount
            )
        );

        // Act
        vm.prank(globalUserAddress);
        pegoutManager.enqueuePegout{value: amountInWei}(userPubKey);
    }

    function test_triggerOperatorTake_FromKickoff_Revert_OperatorTakeTimeoutNotExpired() external {
        // Arrange - setup_operatorTake brings state to KICKOFF
        (, RegisterUserTakeSetup memory setup) = setup_operatorTake();

        // Get operatorTakeUpdatedAt
        PegoutTempInfo memory pegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);
        uint256 operatorTakeUpdatedAt = pegoutInfo.operatorTakeUpdatedAt;

        // Assert - should revert because timeout hasn't expired
        vm.expectRevert(
            abi.encodeWithSelector(
                IPegoutManager.OperatorTakeTimeoutNotExpired.selector,
                operatorTakeUpdatedAt,
                operatorTakeUpdatedAt + TAKE_1_TIMEOUT_DEFAULT
            )
        );
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);
    }

    function test_enqueuePegout_Success() external {
        // Arrange
        setup_multipleRequestAndAcceptPeginFlows(1);
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = VALUE;
        Stream memory stream = streamManager.getStream(amount);
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        // Assert
        uint64 queueLength = pegoutManager.getPegoutQueueLength(stream.streamId);
        assertEq(queueLength, 0, "Initial queue length should be 0");

        uint256 balancePegoutManagerBefore = address(pegoutManager).balance;
        uint256 balanceUserBefore = globalUserAddress.balance;

        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutEnqueued(stream.streamId, userPubKey, globalUserAddress);

        // Act
        vm.prank(globalUserAddress);
        pegoutManager.enqueuePegout{value: amountInWei}(userPubKey);

        // Assert - verify queue length is now 1
        queueLength = pegoutManager.getPegoutQueueLength(stream.streamId);
        assertEq(queueLength, 1, "Queue length should be 1 after enqueue");

        // Assert - verify the correct amount was transferred to PegoutManager
        uint256 balancePegoutManagerAfter = address(pegoutManager).balance;
        uint256 balanceUserAfter = globalUserAddress.balance;
        assertEq(
            balancePegoutManagerAfter - balancePegoutManagerBefore,
            amountInWei,
            "PegoutManager should receive the enqueued amount"
        );
        assertEq(balanceUserBefore - balanceUserAfter, amountInWei, "User should be charged the enqueued amount");
    }

    function test_enqueuePegout_Revert_NoFreeFilledSlot_AlmostFilledQueue() external {
        // Arrange
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = VALUE;
        Stream memory stream = streamManager.getStream(amount);
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);
        uint64 queueLength = Constants.MAX_PEGOUT_QUEUE_SIZE - 1;
        uint64 filledSlotCount = Constants.MAX_PEGOUT_QUEUE_SIZE - 1;

        setup_multipleRequestAndAcceptPeginFlows(filledSlotCount);

        // Fill all available slots to simulate almost full queue
        for (uint64 i = 0; i < filledSlotCount; i++) {
            vm.prank(globalUserAddress);
            pegoutManager.enqueuePegout{value: amountInWei}(userPubKey);
        }

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IPegoutManager.NoFreeFilledSlot.selector, stream.streamId, queueLength, filledSlotCount
            )
        );

        // Act
        vm.prank(globalUserAddress);
        pegoutManager.enqueuePegout{value: amountInWei}(userPubKey);
    }

    function test_enqueuePegout_Revert_PegoutQueueFull() external {
        // Arrange
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = VALUE;
        Stream memory stream = streamManager.getStream(amount);
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);
        uint64 queueLength = Constants.MAX_PEGOUT_QUEUE_SIZE;
        uint64 filledSlotCount = Constants.MAX_PEGOUT_QUEUE_SIZE + 1;

        setup_multipleRequestAndAcceptPeginFlows(filledSlotCount);

        // Fill all available slots to simulate full queue
        for (uint64 i = 0; i < queueLength; i++) {
            vm.prank(globalUserAddress);
            pegoutManager.enqueuePegout{value: amountInWei}(userPubKey);
        }

        assertEq(
            streamManager.getFilledSlotsCount(stream.streamId),
            filledSlotCount,
            "Filled slot count should match expected"
        );

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.PegoutQueueFull.selector, stream.streamId));

        // Act
        vm.prank(globalUserAddress);
        pegoutManager.enqueuePegout{value: amountInWei}(userPubKey);
    }

    function test_tryProcessEnqueuedPegout_Success() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_peginAndSPVs();
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = VALUE;
        Stream memory stream = streamManager.getStream(amount);
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);
        uint64 packetNumber = 0;
        uint64 slotId = 0;

        (BitcoinSignatureData memory expectedSignatureData, bytes32 expectedAcceptPeginTxid) =
            getExpectedBitcoinSignatureData();
        assertEq(setup.acceptPeginTxid, expectedAcceptPeginTxid, "Accept pegin txid should match expected");

        // Set up mock to allow burning this amount
        bridgeMock.setWeisTransferredToUnionBridge(amountInWei);
        // Enqueue a pegout
        vm.prank(globalUserAddress);
        pegoutManager.enqueuePegout{value: amountInWei}(userPubKey);

        // Assert
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutDequeued(stream.streamId, userPubKey, globalUserAddress);

        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutRequested(
            userPubKey,
            COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            expectedSignatureData,
            stream.streamId,
            packetNumber,
            slotId,
            amount
        );

        // Act
        pegoutManager.tryProcessEnqueuedPegout(stream.streamId);

        // Assert - verify the enqueued pegout was processed and queue is now empty
        uint64 queueLength = pegoutManager.getPegoutQueueLength(stream.streamId);
        assertEq(queueLength, 0, "Queue length should be 0 after processing enqueued pegout");

        StreamPosition memory streamPosition = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertTrue(
            streamPosition.pegStatus == PegStatus.USER_TAKE,
            "Peg status should be USER_TAKE after processing enqueued pegout"
        );

        // Act - simulate user take registration for the processed pegout
        pegoutManager.registerUserTake(setup.pegoutTxSPVProof);

        // Assert - verify peg status is now COMPLETED after user take registration
        streamPosition = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertTrue(
            streamPosition.pegStatus == PegStatus.COMPLETED,
            "Peg status should be COMPLETED after processing enqueued pegout"
        );
    }

    function test_tryProcessEnqueuedPegout_Success_FullQueue() external {
        // Arrange
        // Make first pegin manually to get the setup information
        RegisterUserTakeSetup memory setup = setup_peginAndSPVs();

        uint160 startUserAddress = 1;
        address userAddress = address(startUserAddress);
        uint64 enqueueCount = Constants.MAX_PEGOUT_QUEUE_SIZE;

        // Enqueue enough pegouts requests to fill the queue
        (uint64 streamId, bytes memory userPubKey, uint256 amountInWei) =
            setup_enqueuePegouts(startUserAddress, enqueueCount);

        Stream memory stream = streamManager.getStream(VALUE);

        (BitcoinSignatureData memory expectedSignatureData, bytes32 expectedAcceptPeginTxid) =
            getExpectedBitcoinSignatureData();
        assertEq(setup.acceptPeginTxid, expectedAcceptPeginTxid, "Accept pegin txid should match expected");

        // Set up mock to allow burning this amount
        bridgeMock.setWeisTransferredToUnionBridge(amountInWei);

        // Assert
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutDequeued(stream.streamId, userPubKey, userAddress);

        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutRequested(
            userPubKey, COMMITTEE_ID_STREAM_1_COMMITTEE_1, expectedSignatureData, stream.streamId, 0, 0, VALUE
        );

        // Act
        pegoutManager.tryProcessEnqueuedPegout(stream.streamId);

        // Assert - verify the enqueued pegout was processed and queue is now empty
        uint64 queueLength = pegoutManager.getPegoutQueueLength(stream.streamId);
        assertEq(
            queueLength, enqueueCount - 1, "Queue length should be (enqueueCount - 1) after processing enqueued pegout"
        );

        StreamPosition memory streamPosition = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertTrue(
            streamPosition.pegStatus == PegStatus.USER_TAKE,
            "Peg status should be USER_TAKE after processing enqueued pegout"
        );

        // Act - simulate user take registration for the processed pegout
        pegoutManager.registerUserTake(setup.pegoutTxSPVProof);

        // Assert - verify peg status is now COMPLETED after user take registration
        streamPosition = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertTrue(
            streamPosition.pegStatus == PegStatus.COMPLETED,
            "Peg status should be COMPLETED after processing enqueued pegout"
        );
        assertQueueState(streamId, startUserAddress + 1, enqueueCount - 1);
    }

    function test_tryProcessEnqueuedPegout_Success_ProcessFullQueue() external {
        // Arrange
        // Note: Some values are hardcoded to avoid stack too deep issues.
        uint160 startUserAddress = 1;
        uint64 enqueueCount = Constants.MAX_PEGOUT_QUEUE_SIZE;
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        Stream memory stream = streamManager.getStream(VALUE);

        // Make first pegin manually to get the setup information
        RegisterUserTakeSetup[] memory setups = new RegisterUserTakeSetup[](enqueueCount);

        // Loop to create multiple pegins and enqueue pegouts for each, incrementing the user address each time
        for (uint64 i = 0; i < enqueueCount; i++) {
            setups[i] = setup_peginAndSPVs();
            // Increment the user address for the next setup
            address userAddress = address(startUserAddress + i);

            vm.deal(userAddress, 10 ether); // Fund the user address to ensure it can enqueue

            // Enqueue a pegout for this setup
            vm.prank(userAddress);
            pegoutManager.enqueuePegout{value: BtcHelper.satoshiToWei(VALUE)}(userPubKey);
        }

        // Assert queue state is correct before processing
        assertQueueState(setups[0].stream.streamId, startUserAddress, enqueueCount);

        for (uint64 i = 0; i < enqueueCount; i++) {
            // Get expected signature data and accept pegin txid for this setup
            RegisterUserTakeSetup memory setup = setups[i];
            address userAddress = address(startUserAddress + i);

            // Set up mock to allow burning this amount
            bridgeMock.setWeisTransferredToUnionBridge(BtcHelper.satoshiToWei(VALUE));

            // Assert
            vm.expectEmit(address(pegoutManager));
            emit IPegoutManager.PegoutDequeued(stream.streamId, userPubKey, userAddress);

            // Act
            pegoutManager.tryProcessEnqueuedPegout(stream.streamId);

            // Assert - verify the enqueued pegout was processed and queue is reduced by 1
            assertEq(
                pegoutManager.getPegoutQueueLength(stream.streamId),
                enqueueCount - 1 - i,
                "Queue length should be decremented after processing enqueued pegout"
            );

            StreamPosition memory streamPosition = streamManager.getStreamPosition(setup.acceptPeginTxid);
            assertTrue(
                streamPosition.pegStatus == PegStatus.USER_TAKE,
                "Peg status should be USER_TAKE after processing enqueued pegout"
            );

            // Act - simulate user take registration for the processed pegout
            pegoutManager.registerUserTake(setup.pegoutTxSPVProof);

            // Assert - verify peg status is now COMPLETED after user take registration
            streamPosition = streamManager.getStreamPosition(setup.acceptPeginTxid);
            assertTrue(
                streamPosition.pegStatus == PegStatus.COMPLETED,
                "Peg status should be COMPLETED after processing enqueued pegout"
            );
            assertQueueState(stream.streamId, startUserAddress + 1 + i, enqueueCount - 1 - i);
        }

        // Assert - verify the enqueued pegout was processed and queue is now empty
        assertEq(
            pegoutManager.getPegoutQueueLength(stream.streamId),
            0,
            "Queue should be empty after processing all enqueued pegouts"
        );
    }

    function test_tryProcessEnqueuedPegout_Revert_PegoutInProcess() external {
        // Arrange. Get 2 pegins
        setup_peginAndSPVs();
        setup_peginAndSPVs();
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = VALUE;
        Stream memory stream = streamManager.getStream(amount);
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        // Try a pegout. So set pegoutInProcess to true
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);

        // Enqueue a pegout
        vm.prank(globalUserAddress);
        pegoutManager.enqueuePegout{value: amountInWei}(userPubKey);

        // Assert
        assertEq(pegoutManager.getPegoutQueueLength(stream.streamId), 1, "Queue length should be 1 before revert");
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.PegoutInProcess.selector, stream.streamId));

        // Act
        pegoutManager.tryProcessEnqueuedPegout(stream.streamId);

        // Assert - verify the enqueued pegout was not processed and the queue still has one element
        assertEq(pegoutManager.getPegoutQueueLength(stream.streamId), 1, "Queue length should be 1 after revert");
    }

    function test_enqueuePegout_Revert_InvalidCompressedPubKey() external {
        // Arrange
        bytes memory invalidUserPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8baa"; // 1 byte longer
        uint64 amount = VALUE;
        Stream memory stream = streamManager.getStream(amount);
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.InvalidCompressedPubKey.selector, invalidUserPubKey));

        // Act
        vm.prank(globalUserAddress);
        pegoutManager.enqueuePegout{value: amountInWei}(invalidUserPubKey);
    }

    function test_enqueuePegout_Revert_InvalidPublicKeyFirstByte() external {
        // Arrange
        bytes memory invalidUserPubKey = hex"04d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b"; // starts with 0x04 instead of 0x02 or 0x03
        uint64 amount = VALUE;
        Stream memory stream = streamManager.getStream(amount);
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.InvalidCompressedPubKey.selector, invalidUserPubKey));

        // Act
        vm.prank(globalUserAddress);
        pegoutManager.enqueuePegout{value: amountInWei}(invalidUserPubKey);
    }

    function test_enqueuePegout_Revert_StreamNotFoundByDenomination() external {
        // Arrange
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = 555555; // this denomination does not exist
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.StreamNotFoundByDenomination.selector, amount));

        // Act
        vm.prank(globalUserAddress);
        pegoutManager.enqueuePegout{value: amountInWei}(userPubKey);
    }

    function test_enqueuePegout_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = VALUE;
        Stream memory stream = streamManager.getStream(amount);
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);
        pauseContracts();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));

        // Act
        vm.prank(globalUserAddress);
        pegoutManager.enqueuePegout{value: amountInWei}(userPubKey);
    }

    function test_dequeuePegout_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_peginAndSPVs();
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = VALUE;
        Stream memory stream = streamManager.getStream(amount);
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        // Enqueue a pegout
        vm.prank(globalUserAddress);
        pegoutManager.enqueuePegout{value: amountInWei}(userPubKey);

        pauseContracts();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));

        // Act
        pegoutManager.dequeuePegout(stream.streamId);
    }

    function test_tryProcessEnqueuedPegout_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_peginAndSPVs();
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = VALUE;
        Stream memory stream = streamManager.getStream(amount);
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        // Enqueue a pegout
        vm.prank(globalUserAddress);
        pegoutManager.enqueuePegout{value: amountInWei}(userPubKey);

        pauseContracts();

        // Assert
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));

        // Act
        pegoutManager.tryProcessEnqueuedPegout(stream.streamId);
    }

    function test_tryPegout_Revert_EnqueuedPegoutsForStream() external {
        // Arrange
        RegisterUserTakeSetup memory setup = setup_peginAndSPVs();
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = VALUE;
        Stream memory stream = streamManager.getStream(amount);
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        // Enqueue a pegout
        vm.prank(globalUserAddress);
        pegoutManager.enqueuePegout{value: amountInWei}(userPubKey);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.EnqueuedPegoutsForStream.selector, stream.streamId, 1));

        // Try a pegout
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);

        // Assert - verify the enqueued pegout was not processed and the queue still has one element
        assertEq(pegoutManager.getPegoutQueueLength(stream.streamId), 1, "Queue length should be 1 after revert");
    }

    function test_tryProcessEnqueuedPegout_Revert_PegoutInProcess_FromQueue() external {
        // Arrange
        RegisterUserTakeSetup memory setup1 = setup_peginAndSPVs();
        RegisterUserTakeSetup memory setup2 = setup_peginAndSPVs();
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = VALUE;
        Stream memory stream = streamManager.getStream(amount);
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        // Enqueue a pegout
        vm.prank(globalUserAddress);
        pegoutManager.enqueuePegout{value: amountInWei}(userPubKey);
        assertEq(pegoutManager.getPegoutQueueLength(stream.streamId), 1, "Queue length should be 1");

        vm.prank(globalUserAddress);
        pegoutManager.enqueuePegout{value: amountInWei}(userPubKey);
        assertEq(pegoutManager.getPegoutQueueLength(stream.streamId), 2, "Queue length should be 2");

        // Start process first enqueued pegout
        pegoutManager.tryProcessEnqueuedPegout(stream.streamId);

        // Assert
        assertEq(
            pegoutManager.getPegoutQueueLength(stream.streamId),
            1,
            "Queue length should be 1 after processing first pegout"
        );
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.PegoutInProcess.selector, stream.streamId));

        // Act
        pegoutManager.tryProcessEnqueuedPegout(stream.streamId);

        // Assert - verify the enqueued pegout was not processed and the queue still has one element
        assertEq(pegoutManager.getPegoutQueueLength(stream.streamId), 1, "Queue length should be 1 after revert");
    }

    function test_tryProcessEnqueuedPegout_Revert_NoEnqueuedPegout() external {
        uint64 streamId = streamManager.getStream(VALUE).streamId;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.NoEnqueuedPegout.selector, streamId));

        // Act
        pegoutManager.tryProcessEnqueuedPegout(streamId);
    }

    function setup_enqueuePegouts(uint160 startAddress, uint64 count)
        internal
        returns (uint64 streamId, bytes memory userPubKey, uint256 amountInWei)
    {
        userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = VALUE;
        streamId = streamManager.getStream(amount).streamId;
        amountInWei = BtcHelper.satoshiToWei(amount);

        for (uint160 i = 0; i < count; i++) {
            // Setup pegin and accept it.
            setup_peginAndSPVs();

            // Use consecutive addresses for enqueuing pegouts
            address userAddress = address(startAddress + i);
            vm.deal(userAddress, amountInWei);

            // Enqueue a pegout for each user
            vm.prank(userAddress);
            pegoutManager.enqueuePegout{value: amountInWei}(userPubKey);
        }

        // Assert
        uint64 queueLength = pegoutManager.getPegoutQueueLength(streamId);
        assertEq(queueLength, count, "Queue length should be equal to count");
    }

    function assertQueueState(uint64 streamId, uint160 firstAddress, uint64 expectedLength) internal {
        uint64 actualLength = pegoutManager.getPegoutQueueLength(streamId);
        assertEq(actualLength, expectedLength, "Queue length mismatch");

        PegoutRequest[] memory queue = pegoutManager.getPegoutQueueHarness(streamId);

        for (uint160 i = 0; i < expectedLength; i++) {
            address expectedAddress = address(firstAddress + i);
            assertEq(queue[i].userAddress, expectedAddress, "User address mismatch at index");
        }
    }

    function test_dequeuePegout_Success_OnePegoutInQueue() external {
        // Arrange
        uint160 startUserAddress = 1;
        address userAddress = address(startUserAddress);
        uint64 enqueueCount = 1;
        (uint64 streamId, bytes memory userPubKey, uint256 amountInWei) =
            setup_enqueuePegouts(startUserAddress, enqueueCount);

        assertQueueState(streamId, startUserAddress, enqueueCount);
        uint256 balancePegoutManagerBefore = address(pegoutManager).balance;
        uint256 balanceUserBefore = userAddress.balance;

        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutDequeued(streamId, userPubKey, userAddress);

        // Act
        vm.prank(userAddress);
        pegoutManager.dequeuePegout(streamId);

        // Assert - verify queue is decreased by one
        assertQueueState(streamId, startUserAddress, enqueueCount - 1);

        // Assert - verify the correct amount was transferred from PegoutManager
        uint256 balancePegoutManagerAfter = address(pegoutManager).balance;
        uint256 balanceUserAfter = userAddress.balance;
        assertEq(
            balancePegoutManagerAfter + amountInWei,
            balancePegoutManagerBefore,
            "PegoutManager should return the enqueued amount"
        );
        assertEq(balanceUserBefore + amountInWei, balanceUserAfter, "User should be charged the enqueued amount");
    }

    function test_dequeuePegout_Success_FullQueueDequeueFirst() external {
        // Arrange
        uint160 startUserAddress = 1;
        address userAddress = address(startUserAddress);
        uint64 enqueueCount = Constants.MAX_PEGOUT_QUEUE_SIZE;
        (uint64 streamId, bytes memory userPubKey, uint256 amountInWei) =
            setup_enqueuePegouts(startUserAddress, enqueueCount);
        assertQueueState(streamId, startUserAddress, enqueueCount);
        uint256 balancePegoutManagerBefore = address(pegoutManager).balance;
        uint256 balanceUserBefore = userAddress.balance;

        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutDequeued(streamId, userPubKey, userAddress);

        // Act
        vm.prank(userAddress);
        pegoutManager.dequeuePegout(streamId);

        // Assert - verify queue
        assertQueueState(streamId, startUserAddress + 1, enqueueCount - 1);

        // Assert - verify the correct amount was transferred from PegoutManager
        uint256 balancePegoutManagerAfter = address(pegoutManager).balance;
        uint256 balanceUserAfter = userAddress.balance;
        assertEq(
            balancePegoutManagerAfter + amountInWei,
            balancePegoutManagerBefore,
            "PegoutManager should return the enqueued amount"
        );
        assertEq(balanceUserBefore + amountInWei, balanceUserAfter, "User should be charged the enqueued amount");
    }

    function test_dequeuePegout_Success_FullQueueDequeueFromTheMiddle() external {
        // Arrange
        uint160 startUserAddress = 1;
        uint160 middleUser = Constants.MAX_PEGOUT_QUEUE_SIZE / 2;
        address userAddress = address(startUserAddress + middleUser);
        uint64 enqueueCount = Constants.MAX_PEGOUT_QUEUE_SIZE;
        (uint64 streamId, bytes memory userPubKey, uint256 amountInWei) =
            setup_enqueuePegouts(startUserAddress, enqueueCount);
        assertQueueState(streamId, startUserAddress, enqueueCount);
        uint256 balancePegoutManagerBefore = address(pegoutManager).balance;
        uint256 balanceUserBefore = userAddress.balance;

        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutDequeued(streamId, userPubKey, userAddress);

        // Act
        vm.prank(userAddress);
        pegoutManager.dequeuePegout(streamId);

        // Assert - verify queue
        uint64 actualLength = pegoutManager.getPegoutQueueLength(streamId);
        assertEq(actualLength, enqueueCount - 1, "Queue length mismatch");

        PegoutRequest[] memory queue = pegoutManager.getPegoutQueueHarness(streamId);

        // Check before removed address
        for (uint160 i = 0; i < middleUser; i++) {
            address expectedAddress = address(startUserAddress + i);
            assertEq(queue[i].userAddress, expectedAddress, "User address mismatch at index");
        }

        // Check after removed address
        for (uint160 i = middleUser + 1; i < enqueueCount; i++) {
            address expectedAddress = address(startUserAddress + i);
            assertEq(queue[i - 1].userAddress, expectedAddress, "User address mismatch at index");
        }

        // Assert - verify the correct amount was transferred from PegoutManager
        uint256 balancePegoutManagerAfter = address(pegoutManager).balance;
        uint256 balanceUserAfter = userAddress.balance;
        assertEq(
            balancePegoutManagerAfter + amountInWei,
            balancePegoutManagerBefore,
            "PegoutManager should return the enqueued amount"
        );
        assertEq(balanceUserBefore + amountInWei, balanceUserAfter, "User should be charged the enqueued amount");
    }

    function test_dequeuePegout_Success_FullQueueDequeueLast() external {
        // Arrange
        uint160 startUserAddress = 1;
        uint64 enqueueCount = Constants.MAX_PEGOUT_QUEUE_SIZE;
        address userAddress = address(startUserAddress + enqueueCount - 1); // Last user in the queue
        (uint64 streamId, bytes memory userPubKey, uint256 amountInWei) =
            setup_enqueuePegouts(startUserAddress, enqueueCount);
        assertQueueState(streamId, startUserAddress, enqueueCount);
        uint256 balancePegoutManagerBefore = address(pegoutManager).balance;
        uint256 balanceUserBefore = userAddress.balance;

        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutDequeued(streamId, userPubKey, userAddress);

        // Act
        vm.prank(userAddress);
        pegoutManager.dequeuePegout(streamId);

        // Assert - verify queue
        assertQueueState(streamId, startUserAddress, enqueueCount - 1);

        // Assert - verify the correct amount was transferred from PegoutManager
        uint256 balancePegoutManagerAfter = address(pegoutManager).balance;
        uint256 balanceUserAfter = userAddress.balance;
        assertEq(
            balancePegoutManagerAfter + amountInWei,
            balancePegoutManagerBefore,
            "PegoutManager should return the enqueued amount"
        );
        assertEq(balanceUserBefore + amountInWei, balanceUserAfter, "User should be charged the enqueued amount");
    }

    function test_dequeuePegout_Success_AfterProcessingOne() external {
        // Arrange
        uint160 startUserAddress = 1;
        address userA = address(startUserAddress);
        address userB = address(startUserAddress + 1);
        uint64 enqueueCount = 2;
        (uint64 streamId, bytes memory userPubKey, uint256 amountInWei) =
            setup_enqueuePegouts(startUserAddress, enqueueCount);
        assertQueueState(streamId, startUserAddress, enqueueCount);

        // Process the first enqueued pegout (userA) — queue pointer advances past it
        bridgeMock.setWeisTransferredToUnionBridge(amountInWei);
        pegoutManager.tryProcessEnqueuedPegout(streamId);
        assertEq(
            pegoutManager.getPegoutQueueLength(streamId), 1, "Queue length should be 1 after processing first pegout"
        );

        // User A tries to dequeue — should fail because their entry is behind the pointer (already processed)
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.PegoutNotFoundInQueue.selector, streamId, userA));
        vm.prank(userA);
        pegoutManager.dequeuePegout(streamId);
        assertEq(
            pegoutManager.getPegoutQueueLength(streamId), 1, "Queue length should still be 1 after userA fails to dequeue"
        );

        // User B dequeues — should succeed because the pointer is behind their entry
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutDequeued(streamId, userPubKey, userB);
        vm.prank(userB);
        pegoutManager.dequeuePegout(streamId);
        assertEq(pegoutManager.getPegoutQueueLength(streamId), 0, "Queue length should be 0 after userB dequeues");
    }

    function test_dequeuePegout_Revert_NoEnqueuedPegout() external {
        uint64 streamId = streamManager.getStream(VALUE).streamId;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.NoEnqueuedPegout.selector, streamId));

        // Act
        vm.prank(globalUserAddress);
        pegoutManager.dequeuePegout(streamId);
    }

    function test_dequeuePegout_Revert_PegoutNotFoundInQueue() external {
        // Arrange
        uint160 startUserAddress = 1;
        uint64 enqueueCount = Constants.MAX_PEGOUT_QUEUE_SIZE;
        address userAddress = address(startUserAddress + enqueueCount - 1); // Last user in the queue
        (uint64 streamId, bytes memory userPubKey, uint256 amountInWei) =
            setup_enqueuePegouts(startUserAddress, enqueueCount);
        assertQueueState(streamId, startUserAddress, enqueueCount);
        address notInQueueUserAddress = address(startUserAddress + enqueueCount + 1); // User not in the queue

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegoutManager.PegoutNotFoundInQueue.selector, streamId, notInQueueUserAddress)
        );

        // Act
        vm.prank(notInQueueUserAddress);
        pegoutManager.dequeuePegout(streamId);

        // Assert - verify queue
        assertQueueState(streamId, startUserAddress, enqueueCount);
    }

    function test_dequeuePegout_Success_2RequestsSameUser() external {
        // Arrange
        address userAddress = address(uint160(1));
        uint64 enqueueCount = 2;

        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = VALUE;
        uint64 streamId = streamManager.getStream(amount).streamId;
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);
        vm.deal(userAddress, amountInWei * enqueueCount);

        // Enqueue enqueueCount requests for the same user
        for (uint160 i = 0; i < enqueueCount; i++) {
            // Setup pegin and accept it.
            setup_peginAndSPVs();

            // Enqueue a pegout for each user
            vm.prank(userAddress);
            pegoutManager.enqueuePegout{value: amountInWei}(userPubKey);
        }

        // Assert queue initial state
        uint64 actualLength = pegoutManager.getPegoutQueueLength(streamId);
        assertEq(actualLength, enqueueCount, "Queue length mismatch");

        // Assert all the requests in the queue belong to the same user
        PegoutRequest[] memory queue = pegoutManager.getPegoutQueueHarness(streamId);
        for (uint160 i = 0; i < enqueueCount; i++) {
            assertEq(queue[i].userAddress, userAddress, "Queue user address mismatch at expected userAddress");
        }

        // Save balance before dequeue
        uint256 balancePegoutManagerBefore = address(pegoutManager).balance;
        uint256 balanceUserBefore = userAddress.balance;

        // Assert emited event
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutDequeued(streamId, userPubKey, userAddress);

        // Act
        vm.prank(userAddress);
        pegoutManager.dequeuePegout(streamId);

        // Assert final queue length
        actualLength = pegoutManager.getPegoutQueueLength(streamId);
        assertEq(actualLength, enqueueCount - 1, "Queue length mismatch");

        // Assert all the remaining requests in the queue belong to the same user
        queue = pegoutManager.getPegoutQueueHarness(streamId);
        for (uint160 i = 0; i < enqueueCount - 1; i++) {
            assertEq(queue[i].userAddress, userAddress, "Queue user address mismatch at expected userAddress");
        }

        // Assert - verify the correct amount was transferred from PegoutManager
        uint256 balancePegoutManagerAfter = address(pegoutManager).balance;
        uint256 balanceUserAfter = userAddress.balance;
        assertEq(
            balancePegoutManagerAfter + amountInWei,
            balancePegoutManagerBefore,
            "PegoutManager should return the enqueued amount"
        );
        assertEq(balanceUserBefore + amountInWei, balanceUserAfter, "User should be charged the enqueued amount");
    }

    function test_dequeuePegout_Revert_NoEnqueuedPegout_DequeueTwice_OnePegoutInQueue() external {
        // Arrange
        uint160 startUserAddress = 1;
        address userAddress = address(startUserAddress);
        uint64 enqueueCount = 1;
        (uint64 streamId, bytes memory userPubKey, uint256 amountInWei) =
            setup_enqueuePegouts(startUserAddress, enqueueCount);

        assertQueueState(streamId, startUserAddress, enqueueCount);

        // Dequeue user request for the first time
        vm.prank(userAddress);
        pegoutManager.dequeuePegout(streamId);

        // Assert - verify queue is decreased by one
        assertQueueState(streamId, startUserAddress, enqueueCount - 1);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.NoEnqueuedPegout.selector, streamId));

        // Act - try to dequeue the same request again
        vm.prank(userAddress);
        pegoutManager.dequeuePegout(streamId);

        // Assert - verify queue
        assertQueueState(streamId, startUserAddress, enqueueCount - 1);
    }

    function test_dequeuePegout_Revert_PegoutNotFoundInQueue_DequeueTwice_FullQueueDequeueFirst() external {
        // Arrange
        uint160 startUserAddress = 1;
        address userAddress = address(startUserAddress);
        uint64 enqueueCount = Constants.MAX_PEGOUT_QUEUE_SIZE;
        (uint64 streamId, bytes memory userPubKey, uint256 amountInWei) =
            setup_enqueuePegouts(startUserAddress, enqueueCount);
        assertQueueState(streamId, startUserAddress, enqueueCount);

        // Dequeue user request for the first time
        vm.prank(userAddress);
        pegoutManager.dequeuePegout(streamId);

        // Assert - verify queue
        assertQueueState(streamId, startUserAddress + 1, enqueueCount - 1);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.PegoutNotFoundInQueue.selector, streamId, userAddress));

        // Act - Try to dequeue the same request again should revert
        vm.prank(userAddress);
        pegoutManager.dequeuePegout(streamId);

        assertQueueState(streamId, startUserAddress + 1, enqueueCount - 1);
    }

    function test_dequeuePegout_Revert_PegoutNotFoundInQueue_DequeueTwice_FullQueueDequeueFromTheMiddle() external {
        // Arrange
        uint160 startUserAddress = 1;
        uint160 middleUser = Constants.MAX_PEGOUT_QUEUE_SIZE / 2;
        address userAddress = address(startUserAddress + middleUser);
        uint64 enqueueCount = Constants.MAX_PEGOUT_QUEUE_SIZE;
        (uint64 streamId, bytes memory userPubKey, uint256 amountInWei) =
            setup_enqueuePegouts(startUserAddress, enqueueCount);

        assertQueueState(streamId, startUserAddress, enqueueCount);

        // Dequeue user request for the first time
        vm.prank(userAddress);
        pegoutManager.dequeuePegout(streamId);

        // Assert - verify queue
        uint64 actualLength = pegoutManager.getPegoutQueueLength(streamId);
        assertEq(actualLength, enqueueCount - 1, "Queue length mismatch");

        PegoutRequest[] memory queue = pegoutManager.getPegoutQueueHarness(streamId);

        // Check before removed address
        for (uint160 i = 0; i < middleUser; i++) {
            address expectedAddress = address(startUserAddress + i);
            assertEq(queue[i].userAddress, expectedAddress, "User address mismatch at index");
        }

        // Check after removed address
        for (uint160 i = middleUser + 1; i < enqueueCount; i++) {
            address expectedAddress = address(startUserAddress + i);
            assertEq(queue[i - 1].userAddress, expectedAddress, "User address mismatch at index");
        }

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.PegoutNotFoundInQueue.selector, streamId, userAddress));

        // Try to dequeue the same request again should revert
        vm.prank(userAddress);
        pegoutManager.dequeuePegout(streamId);
    }

    function test_dequeuePegout_Revert_PegoutNotFoundInQueue_DequeueTwice_FullQueueDequeueLast() external {
        // Arrange
        uint160 startUserAddress = 1;
        uint64 enqueueCount = Constants.MAX_PEGOUT_QUEUE_SIZE;
        address userAddress = address(startUserAddress + enqueueCount - 1); // Last user in the queue
        (uint64 streamId, bytes memory userPubKey, uint256 amountInWei) =
            setup_enqueuePegouts(startUserAddress, enqueueCount);
        assertQueueState(streamId, startUserAddress, enqueueCount);

        // Dequeue user request for the first time
        vm.prank(userAddress);
        pegoutManager.dequeuePegout(streamId);

        // Assert - verify queue
        assertQueueState(streamId, startUserAddress, enqueueCount - 1);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.PegoutNotFoundInQueue.selector, streamId, userAddress));

        // Act - Try to dequeue the same request again should revert
        vm.prank(userAddress);
        pegoutManager.dequeuePegout(streamId);

        assertQueueState(streamId, startUserAddress, enqueueCount - 1);
    }
}
