// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract, StreamManagerHarness} from "test/helpers/HelperContract.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Pausable} from "src/Pausable.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {BtcTransaction, BtcTxSPVProof, StreamPosition, PegStatus} from "src/interfaces/IPegCommonTypes.sol";
import {BitcoinSignatureData} from "src/interfaces/IBitcoinManager.sol";
import {IPegoutManager, PegoutTempInfo} from "src/interfaces/IPegoutManager.sol";
import {IPeginManager} from "src/interfaces/IPeginManager.sol";
import {IPegManagerBase} from "src/interfaces/IPegManagerBase.sol";
import {Slot, SlotState, Stream, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {ISignatureManager} from "src/interfaces/ISignatureManager.sol";
import {ProofValidator} from "src/ProofValidator.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {Constants} from "src/libraries/Constants.sol";
import {BtcScriptParser} from "src/libraries/BtcScriptParser.sol";
import {Committee} from "src/interfaces/ICommitteeRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BtcTxIn, BtcTxOut} from "src/interfaces/IBitcoinManager.sol";
import {IRbtcBridge} from "src/interfaces/IRbtcBridge.sol";

contract TestPegoutManager is Test, HelperContract {
    // Arrange
    // https://www.blockchain.com/explorer/blocks/btc/879500
    uint64 internal constant PACKET_NUMBER = 0;
    address internal constant RSK_DESTINATION_ADDRESS = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
    uint64 internal setupStreamId;
    uint128 internal setupCommitteeId;
    Committee internal setupExpectedCommittee;

    function setUp() external {
        runTestDeployScript();
        (, Committee memory expectedCommittee, uint128 committeeId) = setup_completeCommitteeAndNewMembers();

        setupExpectedCommittee.aggregatedKey = expectedCommittee.aggregatedKey;
        setupExpectedCommittee.leaderAddress = expectedCommittee.leaderAddress;
        for (uint64 i = 0; i < expectedCommittee.members.length; i++) {
            setupExpectedCommittee.members.push(expectedCommittee.members[i]);
        }
        setupStreamId = expectedCommittee.streamId;
        setupCommitteeId = committeeId;
    }

    function test_tryPegout_Success() external {
        // Arrange
        BtcTxIn[] memory inputs = new BtcTxIn[](2);
        inputs[0] = BtcTxIn({
            txId: 0xb24858ade3e5be49ae63facb93524ddf460d0771f093525dae328b6c435516a2,
            vout: 0,
            sequence: 4294967293,
            scriptSig: hex""
        });
        inputs[1] = BtcTxIn({
            txId: 0xb24858ade3e5be49ae63facb93524ddf460d0771f093525dae328b6c435516a2,
            vout: 1, // Enabler output from accept pegin
            sequence: 4294967293,
            scriptSig: hex""
        });

        BtcTxOut[] memory outputs = new BtcTxOut[](2);
        outputs[0] = BtcTxOut({amount: 999125, scriptPubKey: hex"00143fd2e14f4b448a071e074e1e1879318447f2a266"});
        outputs[1] = BtcTxOut({amount: 540, scriptPubKey: hex"00143fd2e14f4b448a071e074e1e1879318447f2a266"});

        BitcoinSignatureData memory expectedSignatureData = BitcoinSignatureData({
            tx: BtcTransaction({version: 2, inputs: inputs, outputs: outputs, locktime: 0}),
            txid: 0xabfb8bf949dbb4c3cb6d3915b2bef8a143b70fce3b9fd4b4fe9be37f068248ce,
            signatureHash: 0xdd29c8f66fa383866201b7b3f03da54ba426f0da1b14594df99e8eaaa32d520a,
            signatureMessage: hex"000102000000000000002b8084abbfc6f1a5fe96508cb072809c2d082150a6c62d95f8080f7ec35e4cce17685862d673aaad7a4904f7eb4c397f372737f0476a1b1af21e168466de61de2c5f3653a318908b90809fa9dcebdcb183de87e4551b25545400edc916887bc982d397cbbcff87bc5d0c4c70e424f9b830efbad7bf0be479da5d1d1bafdb9798bfd84e32f90f61452c95235739095ef9347def223e2b2a49d799abe42099e5850000000000"
        });

        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        bytes32 txId = 0xb24858ade3e5be49ae63facb93524ddf460d0771f093525dae328b6c435516a2;
        bytes memory scriptPubKey = hex"02f519f51e435c20d38af683ea86862f4591ce8cda248077c2d9a72a76b62f32";

        uint64 amount = 1000000; // 0.01 BTC
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = streamManager.getStream(uint64(amount));
        uint64 packetNumber = 0;
        uint64 slotId = 0;

        streamManager.setSlotHarness(stream.streamId, packetNumber, scriptPubKey, txId, amount, SlotState.FILLED);

        bytes32 expectedPegoutId = calculatePegoutId(stream.streamId, packetNumber, slotId, globalUserAddress);

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
            amount,
            expectedPegoutId
        );

        // Act
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
    }

    function test_tryPegout_fromAcceptPegin_Success() external {
        // Setup
        uint128 committeeId = COMMITTEE_ID_STREAM_1_COMMITTEE_1;
        setup_requestAndAcceptPeginFlow(committeeId);

        // Arrange
        // These values are attached to txIdCounter value in HelperContract.getRequestPeginTxIn().
        // Counter should start in 0, otherwise the test will fail or expectedDigest and userPubKey should be updated.
        BtcTxIn[] memory inputs = new BtcTxIn[](2);
        inputs[0] = BtcTxIn({
            txId: 0x14fdaad7499abf1ef94b3705749fad1d3979cce2dc636e978b83e756bd6ad23a,
            vout: 0,
            sequence: 4294967293,
            scriptSig: hex""
        });
        inputs[1] = BtcTxIn({
            txId: 0x14fdaad7499abf1ef94b3705749fad1d3979cce2dc636e978b83e756bd6ad23a,
            vout: 1, // Enabler output from accept pegin
            sequence: 4294967293,
            scriptSig: hex""
        });

        BtcTxOut[] memory outputs = new BtcTxOut[](2);
        outputs[0] = BtcTxOut({amount: 998250, scriptPubKey: hex"00143fd2e14f4b448a071e074e1e1879318447f2a266"});
        outputs[1] = BtcTxOut({amount: 540, scriptPubKey: hex"00143fd2e14f4b448a071e074e1e1879318447f2a266"});

        BitcoinSignatureData memory expectedSignatureData = BitcoinSignatureData({
            tx: BtcTransaction({version: 2, inputs: inputs, outputs: outputs, locktime: 0}),
            txid: 0xe170b24b41e5bfb912fb4d9ea6688994a2290db667bdf9bcd207202fdc56a3c4,
            signatureHash: 0x0a1043930f6622205d3c54be82a44e2090f38001dc95d188cf7ec4cfa7441ae0,
            signatureMessage: hex"00010200000000000000a0e918b6e29da87a5467ddb8d7f29a4de304b82573887401d0b1fd7b81d4cdccac72564c6204c6e42cdd3fa58fd3314ac25c5e7a7d324d5dd03ee456abdcce386278a9f4ca919d3af59490c32ad58017de5f25e9c95d50c1569249e0f7eb688482d397cbbcff87bc5d0c4c70e424f9b830efbad7bf0be479da5d1d1bafdb9798f81b4776c4bc98417c41f791185dfa89d0789939526bc6907fcdcb6f7490398b0000000000"
        });

        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        uint64 amount = VALUE;
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = streamManager.getStream(amount);
        uint64 slotId = stream.pegoutSlotPointer;
        uint64 packetNumber = stream.pegoutPacketPointer;

        bytes32 expectedPegoutId = calculatePegoutId(stream.streamId, packetNumber, slotId, globalUserAddress);

        // Set up mock to allow burning this amount
        bridgeMock.setWeisTransferredToUnionBridge(amountInWei);

        // Assert
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutRequested(
            userPubKey,
            committeeId,
            expectedSignatureData,
            stream.streamId,
            packetNumber,
            slotId,
            amount,
            expectedPegoutId
        );

        // Act
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
    }

    function test_tryPegout_FromNextPacket_Success() external {
        // Setup
        uint256 pegoutAmount = Constants.SLOTS_PER_PACKET + 10;
        setup_multipleRequestAndAcceptPeginFlows(pegoutAmount);

        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = VALUE;
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);
        uint64 packetNumberExpected = 0;
        uint64 slotIdExpected = 0;
        Stream memory stream;

        // Set up mock to allow burning for all pegouts in this test
        bridgeMock.setWeisTransferredToUnionBridge(amountInWei * pegoutAmount);

        for (uint256 i = 0; i < pegoutAmount; i++) {
            if (i % Constants.SLOTS_PER_PACKET == 0 && i != 0) {
                // We are in a new packet, so we need to update the expected packet number
                packetNumberExpected++;
            }
            slotIdExpected = uint64(i % Constants.SLOTS_PER_PACKET);

            stream = streamManager.getStream(amount);
            assertEq(packetNumberExpected, stream.pegoutPacketPointer, "PacketNumber before tryPegout is not correct");
            assertEq(slotIdExpected, stream.pegoutSlotPointer, "SlotId before tryPegout is not correct");

            // Act
            vm.prank(globalUserAddress);
            pegoutManager.tryPegout{value: amountInWei}(userPubKey);

            // Assert
            stream = streamManager.getStream(amount);
            assertEq(packetNumberExpected, stream.pegoutPacketPointer, "PacketNumber after tryPegout is not correct");
            assertEq(slotIdExpected, stream.pegoutSlotPointer, "SlotId after tryPegoutis not correct");
            Slot memory slot =
                streamManager.getSlot(stream.streamId, stream.pegoutPacketPointer, stream.pegoutSlotPointer);
            assertEq(uint64(slot.state), uint64(SlotState.LOCKED), "Slot was not locked");

            // Complete the slot
            BtcTransaction memory pegoutTx = createPegoutTx(slot.acceptPeginTx, userPubKey, slot.acceptPeginAmount);
            BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);
            pegoutManager.registerUserTake(pegoutTxSPVProof);
        }

        stream = streamManager.getStream(amount);
        assertEq(
            pegoutAmount,
            uint256(stream.pegoutPacketPointer) * Constants.SLOTS_PER_PACKET + stream.pegoutSlotPointer,
            "Pegout amount is not correct"
        );
    }

    function test_tryPegout_Revert_InvalidPublicKeyLength() external {
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

        // Verify pegoutPacketPointer and pegoutSlotPointer advance correctly
        Stream memory updatedStream = streamManager.getStreamById(setup.stream.streamId);
        assertEq(updatedStream.pegoutPacketPointer, 0, "Should be the same packet");
        assertEq(updatedStream.pegoutSlotPointer, 1, "Should advance slot pointer after completed");
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

        // Expect both PegoutRegistered and PacketClosed events
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutRegistered(
            setup.pegoutTxSPVProof.blockHash,
            setup.pegoutTxid,
            setup.acceptPeginTxid,
            COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            streamInfo
        );

        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PacketClosed(setup.stream.streamId, setup.packetNumber);

        // Act: Register the last slot
        pegoutManager.registerUserTake(setup.pegoutTxSPVProof);

        // Assert: Verify the slot was marked as COMPLETED
        Slot memory updatedSlot = streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId);
        assertEq(uint256(updatedSlot.state), uint256(SlotState.COMPLETED), "Slot should be marked as COMPLETED");

        // Verify pegoutPacketPointer and pegoutSlotPointer advance correctly
        Stream memory updatedStream = streamManager.getStreamById(setup.stream.streamId);
        assertEq(updatedStream.pegoutPacketPointer, 1, "Should advance to second packet");
        assertEq(updatedStream.pegoutSlotPointer, 0, "Should advance slot pointer after completed");
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

    function test_registerUserTake_Revert_InvalidAcceptPeginTxid() external {
        // Create a peg-out transaction that spends the accept peg-in UTXO
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        bytes32 acceptPeginTxid = 0x30b6a2cae94d89540a99e0dfa39cf88e6de40dca9142810fdce7a95c00faff47;
        BtcTransaction memory pegoutTx = createPegoutTx(acceptPeginTxid, userPubKey, VALUE);

        // Create a slot
        Stream memory stream = streamManager.getStream(VALUE);
        uint64 packetNumber = 0;
        bytes32 differentTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

        uint64 slotId = streamManager.setSlotHarness(
            stream.streamId,
            packetNumber,
            hex"00143fd2e14f4b448a071e074e1e1879318447f2a266",
            differentTxid, // Different from what the peg-out transaction references
            VALUE,
            SlotState.FILLED
        );

        // Set the slot state to LOCKED
        streamManager.setSlotStateHarness(stream.streamId, packetNumber, slotId, SlotState.LOCKED);

        // Set up the pegoutTxs mapping
        pegoutManager.setPegoutTempInfoHarness(acceptPeginTxid, userPubKey);
        peginManager.setStreamPositionHarness(
            acceptPeginTxid, stream.streamId, packetNumber, slotId, PegStatus.USER_TAKE
        );

        // Create SPV proof for the peg-out transaction
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);

        // Expect revert for invalid accept peg-in tx id
        vm.expectRevert(
            abi.encodeWithSelector(IPeginManager.InvalidAcceptPeginTxid.selector, differentTxid, acceptPeginTxid)
        );

        // Register the peg-out transaction
        pegoutManager.registerUserTake(pegoutTxSPVProof);
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
                ProofValidator.NotEnoughConfirmations.selector, actualConfirmations, setup.stream.peginConfirmations
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
        (BtcTransaction memory requestPeginTx, BtcTransaction memory acceptPeginTx) =
            setup_requestAndAcceptPeginFlow(COMMITTEE_ID_STREAM_1_COMMITTEE_1);

        // Get the accept peg-in tx id that will be spent in the peg-out
        bytes32 acceptPeginTxid = bitcoinManager.getBtcTxid(acceptPeginTx);

        // =================== Request Peg-Out ===================
        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        uint64 pegoutAmount = VALUE; // Same amount as peg-in
        uint256 pegoutAmountInWei = BtcHelper.satoshiToWei(pegoutAmount);

        // Calculate expected values
        Stream memory stream = streamManager.getStream(pegoutAmount);
        uint64 expectedPacketNumber = stream.pegoutPacketPointer;
        uint64 expectedSlotId = stream.pegoutSlotPointer;

        // Set up BridgeMock to allow burning this amount
        bridgeMock.setWeisTransferredToUnionBridge(pegoutAmountInWei);

        // Request peg-out
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: pegoutAmountInWei}(userPubKey);

        // Verify slot was locked
        Slot memory slot = streamManager.getSlot(stream.streamId, expectedPacketNumber, expectedSlotId);
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
                packetNumber: expectedPacketNumber,
                slotId: expectedSlotId,
                pegStatus: PegStatus.USER_TAKE
            })
        );

        // Register peg-out transaction
        pegoutManager.registerUserTake(pegoutTxSPVProof);

        // Validate the full peg-out flow, avoiding stack too deep error
        _validateFullPegoutFlow(
            requestPeginTx, acceptPeginTxid, stream, expectedPacketNumber, expectedSlotId, userPubKey
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

    function test_triggerOperatorTake_Revert_PegoutTxidNotFound() external {
        // Arrange
        bytes32 pegoutTxid = hex"0001";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.PegoutTxidNotFound.selector, pegoutTxid));

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

        // Get the last operator take index
        Committee memory committee = registry.getCommittee(COMMITTEE_ID_STREAM_1_COMMITTEE_1);
        uint256 lastOpTakeIndex = committee.operatorTakeIndex;
        uint256 expectedOpTakeIndex = (lastOpTakeIndex + 3) % committee.members.length;

        // Assert
        address expectedOperator = committee.members[expectedOpTakeIndex].memberAddress;
        assertEventOperatorTakeTriggered(setup.pegoutTxid, setup, expectedOperator, createdAt);

        // Act
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
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

        // Assert
        // By implementation, first operator is skipped.
        assertEventOperatorTakeTriggered(setup.pegoutTxid, setup, secondOpAddress, createdAt);

        // Act
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );
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

        // Assert
        address expectedOperator = committee.members[expectedOpTakeIndex].memberAddress;
        assertEventOperatorTakeTriggered(setup.pegoutTxid, setup, expectedOperator, createdAt);

        // Act
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
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
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);
        // Expire TAKE_1
        vm.warp(block.timestamp + TAKE_1_TIMEOUT_DEFAULT + 1);

        // Assert
        // This call will select the third operator
        assertEventOperatorTakeTriggered(setup.pegoutTxid, setup, thirdOpAddress, createdAt);

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

        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PacketClosed(setup.stream.streamId, setup.packetNumber);

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
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.PeginNotRequested.selector, wrongAcceptPeginTxid));

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
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.InvalidPegStatus.selector, PegStatus.COMPLETED));

        // Act
        vm.prank(operatorAddress);
        pegoutManager.registerOperatorTake(setup.operatorTakeSPV);
    }

    function test_registerOperatorTake_Revert_IncorrectVout() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        setup.operatorTakeSPV.btcTx.inputs[0].vout = Constants.ACCEPT_PEGIN_VOUT_TAPTREE + 1; // Set an incorrect vout

        // Expect the PegoutRegistered event
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

        // Expect the PegoutRegistered event
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

        // Expect the PegoutRegistered event
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

        // Expect the PegoutRegistered event
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
        vm.prank(address(registry));
        streamManager.createNewPacket(
            stream.streamId, COMMITTEE_ID_STREAM_1_COMMITTEE_1, setupExpectedCommittee.aggregatedKey
        );
        streamManager.setSlotHarness(stream.streamId, 1, scriptPubKey, txId, amount, SlotState.FILLED);

        // Set up mock to allow burning this amount
        bridgeMock.setWeisTransferredToUnionBridge(amountInWei);

        // 3. Call tryPegout
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);

        // 4. Verify it skips entire first packet and locks slot in second packet
        Slot memory lockedSlot = streamManager.getSlot(stream.streamId, 1, 0);
        assertEq(uint256(lockedSlot.state), uint256(SlotState.LOCKED), "First slot in second packet should be LOCKED");

        // 5. Verify pegoutPacketPointer have advanced and pegoutSlotPointer is up to the locked slot
        Stream memory updatedStream = streamManager.getStreamById(stream.streamId);
        assertEq(updatedStream.pegoutPacketPointer, 1, "Should advance packet pointer");
        assertEq(updatedStream.pegoutSlotPointer, 0, "Should be up to the locked slot");
    }

    function test_setStreamManager_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newStreamManagerAddress = vm.addr(privKey);
        IStreamManager newStreamManager = IStreamManager(newStreamManagerAddress);
        address owner = pegoutManager.owner();

        // Assert
        vm.expectEmit(address(pegoutManager));
        emit IPegManagerBase.StreamManagerUpdated(newStreamManager);

        // Act
        vm.prank(owner);
        pegoutManager.setStreamManager(newStreamManager);

        // Assert
        assertEq(address(pegoutManager.streamManager()), newStreamManagerAddress);
    }

    function test_setStreamManager_Success_PausedContract() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newStreamManagerAddress = vm.addr(privKey);
        StreamManagerHarness newStreamManager = StreamManagerHarness(newStreamManagerAddress);
        pauseContracts();

        // Assert
        vm.prank(pegoutManager.owner());
        vm.expectEmit(address(pegoutManager));
        emit IPegManagerBase.StreamManagerUpdated(newStreamManager);

        // Act
        pegoutManager.setStreamManager(newStreamManager);

        // Assert
        assertEq(address(pegoutManager.streamManager()), newStreamManagerAddress);
    }

    function test_setStreamManager_Revert_AddressZero() external {
        // Arrange
        address owner = pegoutManager.owner();
        IStreamManager zeroStreamManager = IStreamManager(address(0));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.StreamManagerAddressZero.selector));

        // Act
        vm.prank(owner);
        pegoutManager.setStreamManager(zeroStreamManager);
    }

    function test_setStreamManager_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newStreamManagerAddress = vm.addr(privKey);
        IStreamManager newStreamManager = IStreamManager(newStreamManagerAddress);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        pegoutManager.setStreamManager(newStreamManager);
    }

    function test_setSignatureManager_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newSignatureManagerAddress = vm.addr(privKey);
        ISignatureManager newSignatureManager = ISignatureManager(newSignatureManagerAddress);
        address owner = pegoutManager.owner();

        // Assert
        vm.expectEmit(address(pegoutManager));
        emit IPegManagerBase.SignatureManagerUpdated(newSignatureManager);

        // Act
        vm.prank(owner);
        pegoutManager.setSignatureManager(newSignatureManager);

        // Assert
        assertEq(address(pegoutManager.signatureManager()), newSignatureManagerAddress);
    }

    function test_setSignatureManager_Success_PausedContract() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newSignatureManagerAddress = vm.addr(privKey);
        ISignatureManager newSignatureManager = ISignatureManager(newSignatureManagerAddress);

        pauseContracts();

        // Assert
        vm.prank(pegoutManager.owner());
        vm.expectEmit(address(pegoutManager));
        emit IPegManagerBase.SignatureManagerUpdated(newSignatureManager);

        // Act
        pegoutManager.setSignatureManager(newSignatureManager);

        // Assert
        assertEq(address(pegoutManager.signatureManager()), newSignatureManagerAddress);
    }

    function test_setSignatureManager_Revert_AddressZero() external {
        // Arrange
        address owner = pegoutManager.owner();
        ISignatureManager zeroSignatureManager = ISignatureManager(address(0));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.SignatureManagerAddressZero.selector));

        // Act
        vm.prank(owner);
        pegoutManager.setSignatureManager(zeroSignatureManager);
    }

    function test_setSignatureManager_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newSignatureManagerAddress = vm.addr(privKey);
        ISignatureManager newSignatureManager = ISignatureManager(newSignatureManagerAddress);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        pegoutManager.setSignatureManager(newSignatureManager);
    }

    function test_setPauser_Success() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newPauser = vm.addr(privKey);
        address owner = pegoutManager.owner();

        // Assert
        vm.expectEmit(address(pegoutManager));
        emit Pausable.PauserUpdated(newPauser);

        // Act
        vm.prank(owner);
        pegoutManager.setPauser(newPauser);

        // Assert
        assertEq(pegoutManager.pauser(), newPauser);
    }

    function test_setPauser_Success_PausedContract() external {
        // Arrange
        pauseContracts();

        uint256 privKey = uint256(1);
        address newPauser = vm.addr(privKey);
        address owner = pegoutManager.owner();

        // Assert
        vm.expectEmit(address(pegoutManager));
        emit Pausable.PauserUpdated(newPauser);

        // Act
        vm.prank(owner);
        pegoutManager.setPauser(newPauser);

        // Assert
        assertEq(pegoutManager.pauser(), newPauser);
    }

    function test_setPauser_Revert_OwnableUnauthorizedAccount() external {
        // Arrange
        uint256 privKey = uint256(1);
        address newPauser = vm.addr(privKey);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));

        // Act
        pegoutManager.setPauser(newPauser);
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

    function test_tryPegout_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseContracts();
        BtcTxIn[] memory inputs = new BtcTxIn[](2);
        inputs[0] = BtcTxIn({
            txId: 0xb24858ade3e5be49ae63facb93524ddf460d0771f093525dae328b6c435516a2,
            vout: 0,
            sequence: 4294967293,
            scriptSig: hex""
        });
        inputs[1] = BtcTxIn({
            txId: 0xb24858ade3e5be49ae63facb93524ddf460d0771f093525dae328b6c435516a2,
            vout: 1, // Enabler output from accept pegin
            sequence: 4294967293,
            scriptSig: hex""
        });

        BtcTxOut[] memory outputs = new BtcTxOut[](2);
        outputs[0] = BtcTxOut({amount: 999125, scriptPubKey: hex"00143fd2e14f4b448a071e074e1e1879318447f2a266"});
        outputs[1] = BtcTxOut({amount: 540, scriptPubKey: hex"00143fd2e14f4b448a071e074e1e1879318447f2a266"});

        BitcoinSignatureData memory expectedSignatureData = BitcoinSignatureData({
            tx: BtcTransaction({version: 2, inputs: inputs, outputs: outputs, locktime: 0}),
            txid: 0xabfb8bf949dbb4c3cb6d3915b2bef8a143b70fce3b9fd4b4fe9be37f068248ce,
            signatureHash: 0xdd29c8f66fa383866201b7b3f03da54ba426f0da1b14594df99e8eaaa32d520a,
            signatureMessage: hex"000102000000000000002b8084abbfc6f1a5fe96508cb072809c2d082150a6c62d95f8080f7ec35e4cce17685862d673aaad7a4904f7eb4c397f372737f0476a1b1af21e168466de61de2c5f3653a318908b90809fa9dcebdcb183de87e4551b25545400edc916887bc982d397cbbcff87bc5d0c4c70e424f9b830efbad7bf0be479da5d1d1bafdb9798bfd84e32f90f61452c95235739095ef9347def223e2b2a49d799abe42099e5850000000000"
        });

        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        bytes32 txId = 0xb24858ade3e5be49ae63facb93524ddf460d0771f093525dae328b6c435516a2;
        bytes memory scriptPubKey = hex"02f519f51e435c20d38af683ea86862f4591ce8cda248077c2d9a72a76b62f32";

        uint64 amount = 1000000; // 0.01 BTC
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = streamManager.getStream(uint64(amount));
        uint64 packetNumber = 0;
        uint64 slotId = 0;

        streamManager.setSlotHarness(stream.streamId, packetNumber, scriptPubKey, txId, amount, SlotState.FILLED);

        bytes32 expectedPegoutId = calculatePegoutId(stream.streamId, packetNumber, slotId, address(this));

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
            amount,
            expectedPegoutId
        );

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
        assertEventOperatorTakeTriggered(pegoutTxId, setup, secondOpAddress, createdAt);

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

        // Assert
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.AdvanceFundsRegistered(
            setup.advanceFundsSPV.blockHash,
            txid,
            setup.acceptPeginTxid,
            setup.pegoutId,
            COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            streamInfo
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
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.PeginNotRequested.selector, wrongAcceptPeginTxid));

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
                hex"6a2752c0d7974fcf16967915fa3d5e005af8d3993980c48145aa591ebcc6117776"
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
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.InvalidPegStatus.selector, PegStatus.COMPLETED));

        // Act
        vm.prank(opAddress);
        pegoutManager.registerAdvanceFunds(setup.acceptPeginTxid, setup.advanceFundsSPV);
    }

    function test_registerReimbursementKickoff_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseContracts();
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();
        bytes32 txid = bitcoinManager.getBtcTxid(setup.reimbursementKickoffSPV.btcTx);
        StreamPosition memory streamInfo = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.ADVANCED
        });

        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.ReimbursementKickoffRegistered(
            txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
        );

        // Act
        vm.prank(opAddress);
        pegoutManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);

        streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.KICKOFF));
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
            "Slot state should be ADVANCED"
        );
        PegoutTempInfo memory pegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);
        assertEq(pegoutInfo.reimbursementKickoffTxid, txid, "Reimbursement kickoff txid should be recorded");
    }

    function test_registerReimbursementKickoff_Revert_EnforcedPause_PausedContract() external {
        // Arrange
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
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();
        bytes32 wrongAcceptPeginTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.PeginNotRequested.selector, wrongAcceptPeginTxid));

        // Act
        vm.prank(opAddress);
        pegoutManager.registerReimbursementKickoff(wrongAcceptPeginTxid, setup.reimbursementKickoffSPV);
    }

    function test_registerReimbursementKickoff_Revert_InvalidPegStatus() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_reimbursementKickoff();

        // Set peg status to COMPLETED to trigger invalid status error
        vm.prank(address(pegoutManager));
        streamManager.setPegStatus(setup.acceptPeginTxid, PegStatus.COMPLETED);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.InvalidPegStatus.selector, PegStatus.COMPLETED));

        // Act
        vm.prank(opAddress);
        pegoutManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);
    }

    function getCommitteeMemberAddressByIndex(uint128 committeeId, uint256 index) internal view returns (address) {
        Committee memory committee = registry.getCommittee(committeeId);
        require(index < committee.members.length, "Index out of bounds");
        return committee.members[index].memberAddress;
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

        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.ChallengeRegistered(
            txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
        );

        // Act
        vm.prank(opAddress);
        pegoutManager.registerChallenge(setup.acceptPeginTxid, setup.challengeSPV);

        streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.CHALLENGE));
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
            "Slot state should be ADVANCED"
        );
        PegoutTempInfo memory pegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);
        assertEq(pegoutInfo.challengeTxid, txid, "Challenge txid should be recorded");
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

        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.ChallengeRegistered(
            txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
        );

        // Act
        vm.prank(memberAddress);
        pegoutManager.registerChallenge(setup.acceptPeginTxid, setup.challengeSPV);

        streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.CHALLENGE));
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
            "Slot state should be ADVANCED"
        );
        PegoutTempInfo memory pegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);
        assertEq(pegoutInfo.challengeTxid, txid, "Challenge txid should be recorded");
    }

    function test_registerChallenge_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        pegoutManager.registerChallenge(setup.acceptPeginTxid, setup.challengeSPV);
    }

    function test_registerChallenge_Revert_PeginNotRequested() external {
        // Arrange
        (, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 wrongAcceptPeginTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.PeginNotRequested.selector, wrongAcceptPeginTxid));

        // Act
        pegoutManager.registerChallenge(wrongAcceptPeginTxid, setup.challengeSPV);
    }

    function test_registerChallenge_Revert_InvalidPegStatus() external {
        // Arrange
        (, RegisterUserTakeSetup memory setup) = setup_operatorTake();

        // Set peg status to COMPLETED to trigger invalid status error
        vm.prank(address(pegoutManager));
        streamManager.setPegStatus(setup.acceptPeginTxid, PegStatus.COMPLETED);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.InvalidPegStatus.selector, PegStatus.COMPLETED));

        // Act
        pegoutManager.registerChallenge(setup.acceptPeginTxid, setup.challengeSPV);
    }

    function test_registerChallenge_Revert_ReimbursementKickoffTxidNotMatch() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 txid = bitcoinManager.getBtcTxid(setup.reimbursementKickoffSPV.btcTx);
        bytes32 wrongTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        bytes memory committeePubKey = streamManager.getCommitteePubKey(uint64(DEFAULT_STREAM), setup.packetNumber);
        BtcTxSPVProof memory wrongSPV = createBtcTxSPVProof(createChallengeTx(wrongTxid, committeePubKey));
        address memberAddress = getCommitteeMemberAddressByIndex(COMMITTEE_ID_STREAM_1_COMMITTEE_1, 0);

        assertNotEq(memberAddress, opAddress, "Member address should be different from operator address");

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegoutManager.ReimbursementKickoffTxidNotMatch.selector, wrongTxid, txid)
        );

        // Act
        vm.prank(memberAddress);
        pegoutManager.registerChallenge(setup.acceptPeginTxid, wrongSPV);
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
        pegoutManager.registerChallenge(setup.acceptPeginTxid, setup.challengeSPV);
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

        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.RevealRegistered(txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo);

        // Act
        vm.prank(opAddress);
        pegoutManager.registerInputRevealed(setup.acceptPeginTxid, setup.inputRevealedSPV);

        streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.REVEALED));

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
            "Slot state should be ADVANCED"
        );

        PegoutTempInfo memory pegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);
        assertEq(pegoutInfo.revealTxid, txid, "Input revealed txid should be recorded");
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

        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.RevealRegistered(txid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo);

        // Act
        vm.prank(memberAddress);
        pegoutManager.registerInputRevealed(setup.acceptPeginTxid, setup.inputRevealedSPV);

        streamInfo = streamManager.getStreamPosition(setup.acceptPeginTxid);
        assertEq(uint256(streamInfo.pegStatus), uint256(PegStatus.REVEALED));

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED,
            "Slot state should be ADVANCED"
        );

        PegoutTempInfo memory pegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);
        assertEq(pegoutInfo.revealTxid, txid, "Input revealed txid should be recorded");
    }

    function test_registerInputRevealed_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(opAddress);
        pegoutManager.registerInputRevealed(setup.acceptPeginTxid, setup.inputRevealedSPV);
    }

    function test_registerInputRevealed_Revert_PeginNotRequested() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        bytes32 wrongAcceptPeginTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.PeginNotRequested.selector, wrongAcceptPeginTxid));

        // Act
        vm.prank(opAddress);
        pegoutManager.registerInputRevealed(wrongAcceptPeginTxid, setup.inputRevealedSPV);
    }

    function test_registerInputRevealed_Revert_InvalidPegStatus() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();

        // Set peg status to COMPLETED to trigger invalid status error
        vm.prank(address(pegoutManager));
        streamManager.setPegStatus(setup.acceptPeginTxid, PegStatus.COMPLETED);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegManagerBase.InvalidPegStatus.selector, PegStatus.COMPLETED));

        // Act
        vm.prank(opAddress);
        pegoutManager.registerInputRevealed(setup.acceptPeginTxid, setup.inputRevealedSPV);
    }

    function test_registerInputRevealed_Revert_ChallengeTxidNotMatch() external {
        // Arrange
        (address opAddress, RegisterUserTakeSetup memory setup) = setup_challenge();
        bytes32 txid = bitcoinManager.getBtcTxid(setup.challengeSPV.btcTx);
        bytes32 wrongTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        bytes memory committeePubKey = streamManager.getCommitteePubKey(uint64(DEFAULT_STREAM), setup.packetNumber);
        BtcTxSPVProof memory wrongSPV = createBtcTxSPVProof(createRevealTx(wrongTxid, committeePubKey));

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.ChallengeTxidNotMatch.selector, wrongTxid, txid));

        // Act
        vm.prank(opAddress);
        pegoutManager.registerInputRevealed(setup.acceptPeginTxid, wrongSPV);
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
        uint64 slotId = stream.pegoutSlotPointer;
        uint64 packetNumber = stream.pegoutPacketPointer;
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
        uint64 slotId = stream.pegoutSlotPointer;
        uint64 packetNumber = stream.pegoutPacketPointer;
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
        uint64 slotId = stream.pegoutSlotPointer;
        uint64 packetNumber = stream.pegoutPacketPointer;
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
        uint64 slotId = stream.pegoutSlotPointer;
        uint64 packetNumber = stream.pegoutPacketPointer;
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
}
