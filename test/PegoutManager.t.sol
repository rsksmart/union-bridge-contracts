// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract, StreamManagerHarness} from "test/helpers/HelperContract.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Pausable} from "src/Pausable.sol";
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
        BtcTxIn[] memory inputs = new BtcTxIn[](1);
        inputs[0] = BtcTxIn({
            txId: 0xb24858ade3e5be49ae63facb93524ddf460d0771f093525dae328b6c435516a2,
            vout: 0,
            sequence: 4294967293,
            scriptSig: hex""
        });

        BtcTxOut[] memory outputs = new BtcTxOut[](2);
        outputs[0] = BtcTxOut({amount: 999125, scriptPubKey: hex"00143fd2e14f4b448a071e074e1e1879318447f2a266"});
        outputs[1] = BtcTxOut({amount: 540, scriptPubKey: hex"00143fd2e14f4b448a071e074e1e1879318447f2a266"});

        BitcoinSignatureData memory expectedSignatureData = BitcoinSignatureData({
            tx: BtcTransaction({version: 2, inputs: inputs, outputs: outputs, locktime: 0}),
            txid: 0x797853a318220995510a2cfd90f40ee81ca9931896fd9f86e4681ac925e2c1fc,
            signatureHash: 0xfb6d69787860ef13b81041a168cb1f530eb5d87973d34430fc9eb8cef62eb7ad,
            signatureMessage: hex"00010200000000000000234337e863e00e6ff45f167a14f3963bea912bc0d739c2b402d04f376e814ae24f973621fe8403b6facae9abab80d863a847d3fb007ba2f9830f8e16e6e9b4d4a0c6dbc3091625a23fd870bf8d09182484c12fa63a5c29045a431cf445f153e523e9829bfb4e23fbd3c4848baa035af15d73bcb83e510f7f097f90a21a4280d2bfd84e32f90f61452c95235739095ef9347def223e2b2a49d799abe42099e5850000000000"
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

        // Calculate expected PegoutId using mock block hash
        bytes32 mockBlockHash = 0x0000000000000000000049b460f18614380a01b8709d2c3a8ddf451d08d862b8;
        bytes32 expectedPegoutId =
            keccak256(abi.encode(stream.streamId, packetNumber, slotId, address(this), mockBlockHash));

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
        setup_requestAndAcceptPeginFlow();

        // Arrange
        // These values are attached to txIdCounter value in HelperContract.getPeginRequestTxIn().
        // Counter should start in 0, otherwise the test will fail or expectedDigest and userPubKey should be updated.
        BtcTxIn[] memory inputs = new BtcTxIn[](1);
        inputs[0] = BtcTxIn({
            txId: 0x5acf9ba03e33879b175ce2d5a826a418b753452613df27137c558c44f36711ba,
            vout: 0,
            sequence: 4294967293,
            scriptSig: hex""
        });

        BtcTxOut[] memory outputs = new BtcTxOut[](2);
        outputs[0] = BtcTxOut({amount: 998250, scriptPubKey: hex"00143fd2e14f4b448a071e074e1e1879318447f2a266"});
        outputs[1] = BtcTxOut({amount: 540, scriptPubKey: hex"00143fd2e14f4b448a071e074e1e1879318447f2a266"});

        BitcoinSignatureData memory expectedSignatureData = BitcoinSignatureData({
            tx: BtcTransaction({version: 2, inputs: inputs, outputs: outputs, locktime: 0}),
            txid: 0xdd83f9ce809828c7e7715c33aebe10960ab6c5ad763ee4a23687c612815e2e37,
            signatureHash: 0xc151063d7a30a584ccd02ec37a51dadca1545fdf232f4d0a1435bb025d5b15dc,
            signatureMessage: hex"00010200000000000000c369745d8920f99556e50cac4392807dd9050a35f34ec9b94861cc49b5aabdcdc35d473d9e25f1af7cffe3004bcca82430a4dbea0076331b74ddf0a584963b81be45ad9e08ae96e42d7fd1f70a454432049ebd6a625fa377ffa22033fd8692d623e9829bfb4e23fbd3c4848baa035af15d73bcb83e510f7f097f90a21a4280d2f81b4776c4bc98417c41f791185dfa89d0789939526bc6907fcdcb6f7490398b0000000000"
        });

        bytes memory userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        uint64 amount = VALUE;
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = streamManager.getStream(amount);
        uint64 slotId = stream.pegoutSlotPointer;
        uint64 packetNumber = stream.pegoutPacketPointer;

        // Calculate expected PegoutId using mock block hash
        bytes32 mockBlockHash = 0x0000000000000000000049b460f18614380a01b8709d2c3a8ddf451d08d862b8;
        bytes32 expectedPegoutId =
            keccak256(abi.encode(stream.streamId, packetNumber, slotId, address(this), mockBlockHash));

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

        for (uint256 i = 0; i < pegoutAmount; i++) {
            if (i % Constants.SLOTS_PER_PACKET == 0 && i != 0) {
                // We are in a new packet, so we need to update the expected packet number
                packetNumberExpected++;
            }
            slotIdExpected = uint64(i % Constants.SLOTS_PER_PACKET);

            stream = streamManager.getStream(amount);
            uint64 packetNumber = stream.pegoutPacketPointer;
            uint64 slotId = stream.pegoutSlotPointer;
            assertEq(packetNumberExpected, packetNumber);
            assertEq(slotIdExpected, slotId);

            // Act
            pegoutManager.tryPegout{value: amountInWei}(userPubKey);

            // Assert
            Slot memory slot = streamManager.getSlot(stream.streamId, packetNumber, slotId);
            assertEq(uint64(slot.state), uint64(SlotState.LOCKED), "Slot was not locked");
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
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);
    }

    // we only check the revert case since the success cases are being checked in the _addMemberSignaturePegout tests
    function test_checkAllSignaturesReady_Revert_PegoutRequestNotFound() external {
        // Arrange
        bytes32 pegoutSignatureHash = 0x0000000000000000000000000000000000000000000000000000000000000001;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(ISignatureManager.HashToSignNotFound.selector, pegoutSignatureHash));

        // Act
        signatureManager.checkAllSignaturesReady(pegoutSignatureHash);
    }

    function test_registerUserTake_success() external {
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
            acceptPeginTxid, stream.streamId, packetNumber, slotId, PegStatus.ACCEPTED
        );

        // Create SPV proof for the peg-out transaction
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);

        // Set mock bridge confirmations
        bridgeMock.setBtcTransactionConfirmations(10);

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
            abi.encodeWithSelector(IPegoutManager.IncorrectVout.selector, uint32(1), Constants.VOUT_INDEX_TAPTREE)
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
        (BtcTransaction memory requestPeginTx, BtcTransaction memory acceptPeginTx) = setup_requestAndAcceptPeginFlow();

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

        // Request peg-out
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

        // Add just 2 signatures for the first and second operators
        setup_addMemberSignature_MultipleMembers(setup.pegoutTxid, firstHonestOpIndex, 2);

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
        bytes32 operatorPubKey = getMemberTakePubKey(operatorAddress);
        BtcTransaction memory pegoutTx =
            createPegoutTx(setup.acceptPeginTxid, BtcHelper.pubKeyXonlyToCompact(operatorPubKey), VALUE);
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);
        bytes32 pegoutTxid = bitcoinManager.getBtcTxid(pegoutTx);

        StreamPosition memory streamInfo = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.OPERATOR_TAKE
        });

        // Expect the PegoutRegistered event
        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.PegoutRegistered(
            pegoutTxSPVProof.blockHash, pegoutTxid, setup.acceptPeginTxid, COMMITTEE_ID_STREAM_1_COMMITTEE_1, streamInfo
        );

        // Act
        vm.prank(operatorAddress);
        pegoutManager.registerOperatorTake(pegoutTxSPVProof);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.COMPLETED
        );
    }

    function test_registerOperatorTake_Revert_PeginNotRequested() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 operatorPubKey = getMemberTakePubKey(operatorAddress);
        bytes32 wrongAcceptPeginTxid = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
        BtcTransaction memory pegoutTx =
            createPegoutTx(wrongAcceptPeginTxid, BtcHelper.pubKeyXonlyToCompact(operatorPubKey), VALUE);
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.PeginNotRequested.selector, wrongAcceptPeginTxid));

        // Act
        vm.prank(operatorAddress);
        pegoutManager.registerOperatorTake(pegoutTxSPVProof);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );
    }

    function test_registerOperatorTake_Revert_InvalidPegStatus() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 operatorPubKey = getMemberTakePubKey(operatorAddress);
        BtcTransaction memory pegoutTx =
            createPegoutTx(setup.acceptPeginTxid, BtcHelper.pubKeyXonlyToCompact(operatorPubKey), VALUE);
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);
        // Register Pegout as Take 0
        pegoutManager.registerUserTake(setup.pegoutTxSPVProof);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegoutManager.InvalidPegStatus.selector, PegStatus.COMPLETED));

        // Act
        vm.prank(operatorAddress);
        pegoutManager.registerOperatorTake(pegoutTxSPVProof);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.COMPLETED
        );
    }

    function test_registerOperatorTake_Revert_IncorrectVout() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 operatorPubKey = getMemberTakePubKey(operatorAddress);
        BtcTransaction memory pegoutTx =
            createPegoutTx(setup.acceptPeginTxid, BtcHelper.pubKeyXonlyToCompact(operatorPubKey), VALUE);
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);
        pegoutTxSPVProof.btcTx.inputs[0].vout = Constants.VOUT_INDEX_TAPTREE + 1; // Set an incorrect vout

        // Expect the PegoutRegistered event
        vm.expectRevert(
            abi.encodeWithSelector(
                IPegoutManager.IncorrectVout.selector, Constants.VOUT_INDEX_TAPTREE + 1, Constants.VOUT_INDEX_TAPTREE
            )
        );

        // Act
        vm.prank(operatorAddress);
        pegoutManager.registerOperatorTake(pegoutTxSPVProof);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );
    }

    function test_registerOperatorTake_Revert_IncorrectOutputScript() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 operatorPubKey = getMemberTakePubKey(operatorAddress);
        address wrongOperator = vm.addr(1);
        bytes32 wrongOperatorPubKey = getMemberTakePubKey(wrongOperator);

        BtcTransaction memory pegoutTx =
            createPegoutTx(setup.acceptPeginTxid, BtcHelper.pubKeyXonlyToCompact(wrongOperatorPubKey), VALUE);
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);

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
        pegoutManager.registerOperatorTake(pegoutTxSPVProof);

        // Assert
        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );
    }

    function test_registerOperatorTake_Revert_OperatorTakeAddressNotMatch() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 operatorPubKey = getMemberTakePubKey(operatorAddress);
        address wrongOperator = vm.addr(1);

        BtcTransaction memory pegoutTx =
            createPegoutTx(setup.acceptPeginTxid, BtcHelper.pubKeyXonlyToCompact(operatorPubKey), VALUE);
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);

        // Expect the PegoutRegistered event
        vm.expectRevert(
            abi.encodeWithSelector(IPegoutManager.OperatorTakeAddressNotMatch.selector, operatorAddress, wrongOperator)
        );

        // Act
        vm.prank(wrongOperator);
        pegoutManager.registerOperatorTake(pegoutTxSPVProof);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.ADVANCED
        );
    }

    function test_registerOperatorTake_Revert_InvalidSlotState() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 operatorPubKey = getMemberTakePubKey(operatorAddress);
        BtcTransaction memory pegoutTx =
            createPegoutTx(setup.acceptPeginTxid, BtcHelper.pubKeyXonlyToCompact(operatorPubKey), VALUE);
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);
        // Set slot as COMPLETED
        streamManager.setSlotStateHarness(setup.stream.streamId, setup.packetNumber, setup.slotId, SlotState.COMPLETED);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IStreamManager.InvalidSlotState.selector, SlotState.COMPLETED, SlotState.LOCKED)
        );

        // Act
        vm.prank(operatorAddress);
        pegoutManager.registerOperatorTake(pegoutTxSPVProof);

        assertTrue(
            streamManager.getSlot(setup.stream.streamId, setup.packetNumber, setup.slotId).state == SlotState.COMPLETED
        );
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

        // 2. Call tryPegout should skip blocked slot and lock filled slot
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

        // 3. Call tryPegout
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);

        // 4. Verify it skips entire first packet and locks slot in second packet
        Slot memory lockedSlot = streamManager.getSlot(stream.streamId, 1, 0);
        assertEq(uint256(lockedSlot.state), uint256(SlotState.LOCKED), "First slot in second packet should be LOCKED");

        // 5. Verify pegoutPacketPointer and pegoutSlotPointer advance correctly
        Stream memory updatedStream = streamManager.getStreamById(stream.streamId);
        assertEq(updatedStream.pegoutPacketPointer, 1, "Should advance to second packet");
        assertEq(updatedStream.pegoutSlotPointer, 1, "Should advance slot pointer after locking");
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
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);
    }

    function test_tryPegout_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseContracts();
        // Arrange
        BtcTxIn[] memory inputs = new BtcTxIn[](1);
        inputs[0] = BtcTxIn({
            txId: 0xb24858ade3e5be49ae63facb93524ddf460d0771f093525dae328b6c435516a2,
            vout: 0,
            sequence: 4294967293,
            scriptSig: hex""
        });

        BtcTxOut[] memory outputs = new BtcTxOut[](2);
        outputs[0] = BtcTxOut({amount: 999125, scriptPubKey: hex"00143fd2e14f4b448a071e074e1e1879318447f2a266"});
        outputs[1] = BtcTxOut({amount: 540, scriptPubKey: hex"00143fd2e14f4b448a071e074e1e1879318447f2a266"});

        BitcoinSignatureData memory expectedSignatureData = BitcoinSignatureData({
            tx: BtcTransaction({version: 2, inputs: inputs, outputs: outputs, locktime: 0}),
            txid: 0x797853a318220995510a2cfd90f40ee81ca9931896fd9f86e4681ac925e2c1fc,
            signatureHash: 0xfb6d69787860ef13b81041a168cb1f530eb5d87973d34430fc9eb8cef62eb7ad,
            signatureMessage: hex"00010200000000000000234337e863e00e6ff45f167a14f3963bea912bc0d739c2b402d04f376e814ae24f973621fe8403b6facae9abab80d863a847d3fb007ba2f9830f8e16e6e9b4d4a0c6dbc3091625a23fd870bf8d09182484c12fa63a5c29045a431cf445f153e523e9829bfb4e23fbd3c4848baa035af15d73bcb83e510f7f097f90a21a4280d2bfd84e32f90f61452c95235739095ef9347def223e2b2a49d799abe42099e5850000000000"
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

        // Calculate expected PegoutId using mock block hash
        bytes32 mockBlockHash = 0x0000000000000000000049b460f18614380a01b8709d2c3a8ddf451d08d862b8;
        bytes32 expectedPegoutId =
            keccak256(abi.encode(stream.streamId, packetNumber, slotId, address(this), mockBlockHash));

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
        pegoutManager.tryPegout{value: amountInWei}(userPubKey);
    }

    function test_registerUserTake_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        RegisterUserTakeSetup memory pegoutSetup = setup_pegout();
        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        pegoutManager.registerUserTake(pegoutSetup.pegoutTxSPVProof);
    }

    function test_registerUserTake_Success_UnpausedContract() external {
        // Arrange
        RegisterUserTakeSetup memory pegoutSetup = setup_pegout();
        pauseAndUnpauseContracts();

        // Act
        pegoutManager.registerUserTake(pegoutSetup.pegoutTxSPVProof);
    }

    function test_triggerOperatorTake_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        RegisterUserTakeSetup memory pegoutSetup = setup_pegout();
        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        pegoutManager.triggerOperatorTake(pegoutSetup.pegoutSignatureHash);
    }

    function test_triggerOperatorTake_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseContracts();
        RegisterUserTakeSetup memory pegoutSetup = setup_pegout();
        bytes32 pegoutTxId = pegoutSetup.pegoutTxid;
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
        assertEventOperatorTakeTriggered(pegoutTxId, pegoutSetup, secondOpAddress, createdAt);

        // Act
        pegoutManager.triggerOperatorTake(pegoutTxId);
    }

    function test_registerOperatorTake_Revert_EnforcedPause_PausedContract() external {
        // Arrange
        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 operatorPubKey = getMemberTakePubKey(operatorAddress);
        BtcTransaction memory pegoutTx =
            createPegoutTx(setup.acceptPeginTxid, BtcHelper.pubKeyXonlyToCompact(operatorPubKey), VALUE);
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);

        pauseContracts();

        // Assert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);

        // Act
        vm.prank(operatorAddress);
        pegoutManager.registerOperatorTake(pegoutTxSPVProof);
    }

    function test_registerOperatorTake_Success_UnpausedContract() external {
        // Arrange
        pauseAndUnpauseContracts();

        (address operatorAddress, RegisterUserTakeSetup memory setup) = setup_operatorTake();
        bytes32 operatorPubKey = getMemberTakePubKey(operatorAddress);
        BtcTransaction memory pegoutTx =
            createPegoutTx(setup.acceptPeginTxid, BtcHelper.pubKeyXonlyToCompact(operatorPubKey), VALUE);
        BtcTxSPVProof memory pegoutTxSPVProof = createBtcTxSPVProof(pegoutTx);

        // Act
        vm.prank(operatorAddress);
        pegoutManager.registerOperatorTake(pegoutTxSPVProof);
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
}
