// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {
    PrevoutData,
    BtcTransaction,
    BtcTxSPVProof,
    StreamPosition,
    RequestPegInTempInfo,
    PegStatus,
    IPegManager
} from "src/interfaces/IPegManager.sol";
import {P2TR_FEES, SPEED_UP_AMOUNT, BtcTxIn, BtcTxOut} from "src/interfaces/IBitcoinManager.sol";
import {Slot, SlotState, Packet, Stream, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE} from "src/interfaces/IBridge.sol";
import {ProofValidator} from "src/ProofValidator.sol";
import {BtcTaproot} from "src/libraries/BtcTaproot.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";

contract TestPegManager is Test, HelperContract {
    // Arrange
    // https://www.blockchain.com/explorer/blocks/btc/879500
    bytes32 internal constant BLOCK_HASH = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
    uint64 internal constant PACKET_NUMBER = 0;
    address internal constant RSK_DESTINATION_ADDRESS = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;

    bytes32 internal constant BTC_REIMBURSEMENT_PUBKEY =
        0x5d238354a7e74c9e373317053226537dec221c5c775bcca01e806ec358c5c08d;

    // For more info about this see: https://book.getfoundry.sh/forge/writing-tests#before-test-setups
    function beforeTestSetup(bytes4 testSelector) public pure returns (bytes[] memory beforeTestCalldata) {
        if (
            testSelector == this.test_acceptPegInRequest_Success.selector
                || testSelector == this.test_acceptPegInRequest_Revert_AlreadyRegisteredAcceptPegIn.selector
                || testSelector == this.test_acceptPegInRequest_Revert_IncorrectInputsNumber.selector
                || testSelector == this.test_acceptPegInRequest_Revert_IncorrectOutputsNumber.selector
                || testSelector == this.test_acceptPegInRequest_Revert_InvalidVout.selector
                || testSelector == this.test_acceptPegInRequest_Revert_Revert_NotEnoughConfirmations.selector
        ) {
            beforeTestCalldata = new bytes[](1);
            beforeTestCalldata[0] = abi.encodePacked(this.test_registerPegInRequest_Success.selector);
        }
    }

    function setUp() external {
        runTestDeployScript();
    }

    function test_getTemporaryPegInAddress_Success() external view {
        address dummyRskAddress = 0x4C9a9CbFa14106439B0F96a64d9260F3b8947934;
        string memory tempAddress = "bcrt1ptp8gw3yt9rjavkrlxhwmlm9y5w4c5u6yeeltmupanle76eq4ftrszyjhnn";

        string memory result = pm.getTemporaryPegInAddress(dummyRskAddress, VALUE, BTC_REIMBURSEMENT_PUBKEY);
        assertEq(result, tempAddress, "Incorrect temporary peg in address");
    }

    // ========================== REGISTER PEG IN REQUEST ==========================
    function test_registerPegInRequest_Success() external {
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPegInRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInRequestTxSPVProof = BtcTxSPVProof({
            blockHash: BLOCK_HASH,
            btcTx: btcTransaction,
            //values obtained from https://github.com/FairgateLabs/rust-bitvmx-transactions/blob/main/src/bin/bridge-pmt.rs
            merkleBranchPath: 949,
            merkleBranchHashes: new bytes32[](12)
        });
        pegInRequestTxSPVProof.merkleBranchHashes[0] =
            0x480fd40f2e47eeea8edeef2f7f3e2c680642f748c989ed2e542fe5d28164da51;
        pegInRequestTxSPVProof.merkleBranchHashes[1] =
            0x95c002b26f393d620ca12515bb4ff266617f56efe6b944e5e284f5124a1310ea;
        pegInRequestTxSPVProof.merkleBranchHashes[2] =
            0x5c6e854f9a71ae76fd2ae7ee98b25cf452d49731a70e00bd10aca0bee7265b2e;
        pegInRequestTxSPVProof.merkleBranchHashes[3] =
            0xaa27307f38abf6c00f34941cefffcba573dc6eb4220e46b13a9230f49d2a7d20;
        pegInRequestTxSPVProof.merkleBranchHashes[4] =
            0x93835ab7468acbd3ba3baef1a014787d391a9a11cae31f06037ac87cfde469e5;
        pegInRequestTxSPVProof.merkleBranchHashes[5] =
            0x25877bd79f156e5f242142d34968aada8ac92cf0908aacc9f48313b6b2a73adb;
        pegInRequestTxSPVProof.merkleBranchHashes[6] =
            0xa1a1e0737442b3e1248e88c5a6cac8307cd3e788e654b20809529d7765b84e33;
        pegInRequestTxSPVProof.merkleBranchHashes[7] =
            0x232432f75c9a979619d3315d65634ac83c2c778cedfd4cdfdf05baf363c43c8c;
        pegInRequestTxSPVProof.merkleBranchHashes[8] =
            0xbb822f3484e435d95647c70e837f11fb5287cd4477acd021b462b0cb8b7cb893;
        pegInRequestTxSPVProof.merkleBranchHashes[9] =
            0x46f6681d15564294d83a040b5e42403d2d594d4a55aebecd1f5264be9b9f1563;
        pegInRequestTxSPVProof.merkleBranchHashes[10] =
            0xfe31a4dff5d25fa665b18afea5256f9f71cfdabdd55930eccdf418414cfefd99;
        pegInRequestTxSPVProof.merkleBranchHashes[11] =
            0x512113f66433c1db50f001198988b3a187390df8b52afb48cedae934ae022998;

        // Assert
        vm.expectEmit(address(pm));
        // We emit the event we expect to see.
        emit IPegManager.RegisteredPegInRequest(
            pegInRequestTxSPVProof.blockHash,
            getExpectedPegInRequestTxHash(),
            0,
            VALUE,
            PACKET_NUMBER,
            RSK_DESTINATION_ADDRESS,
            BTC_REIMBURSEMENT_PUBKEY,
            btcTransaction.outputs[0].scriptPubKey
        );

        // Act
        pm.registerPegInRequest(pegInRequestTxSPVProof);

        // Assert
        bytes32 txHash = getExpectedPegInRequestTxHash();
        // Registered Peg In
        StreamPosition memory streamPosition = pm.getPegInRequest(txHash);
        assertEq(streamPosition.streamId, 0, "Incorrect streamId registered");
        assertEq(streamPosition.packetNumber, 0, "Incorrect packetNumber registered");
        assertEq(uint256(streamPosition.pegStatus), uint256(PegStatus.REGISTERED), "PegIn Request was not registered");
        // Registered Peg In Temp info
        RequestPegInTempInfo memory pegInTempInfo = pm.getRequestPegInTempInfo(txHash);
        assertEq(pegInTempInfo.outputAmount, VALUE, "Incorrect peg in temp info value");
        assertEq(
            pegInTempInfo.rskDestinationAddress,
            RSK_DESTINATION_ADDRESS,
            "Incorrect peg in temp info destinationAddress"
        );
        assertEq(
            pegInTempInfo.btcReimbursementPubKey,
            BTC_REIMBURSEMENT_PUBKEY,
            "Incorrect peg in temp info btcReimbursementPubKey"
        );
        assertEq(
            pegInTempInfo.utxoScriptPubKey,
            btcTransaction.outputs[0].scriptPubKey,
            "Incorrect peg in temp info utxo script pub key"
        );
    }

    function test_registerPegInRequest_Revert_AlreadyRegistered() external {
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPegInRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInRequestTxSPVProof = BtcTxSPVProof({
            blockHash: BLOCK_HASH,
            btcTx: btcTransaction,
            // merkle branch values are fake, we don't need them for this test
            // to get actual values use https://github.com/FairgateLabs/rust-bitvmx-transactions/blob/main/src/bin/bridge-pmt.rs
            merkleBranchPath: 4285202432,
            merkleBranchHashes: new bytes32[](1)
        });
        pegInRequestTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Register First Peg In Request
        pm.registerPegInRequest(pegInRequestTxSPVProof);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegManager.AlreadyRegisteredPegInRequest.selector, getExpectedPegInRequestTxHash())
        );

        // Act Register Second Peg In Request
        pm.registerPegInRequest(pegInRequestTxSPVProof);
    }

    function test_registerPegInRequest_Revert_NotEnoughConfirmations() external {
        // Arrange
        int256 actualConfirmations = 0;
        BtcTransaction memory btcTransaction = getBtcPegInRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInRequestTxSPVProof = BtcTxSPVProof({
            blockHash: BLOCK_HASH,
            btcTx: btcTransaction,
            merkleBranchPath: 1,
            merkleBranchHashes: new bytes32[](1)
        });
        pegInRequestTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        Stream memory stream = pm.getStream(VALUE);
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.NotEnoughConfirmations.selector, actualConfirmations, stream.pegInConfirmations
            )
        );
        // Act
        pm.registerPegInRequest(pegInRequestTxSPVProof);
    }

    function test_registerPegInRequest_Revert_BridgeBtcTxInvalidMerkleBranch() external {
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPegInRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInRequestTxSPVProof = BtcTxSPVProof({
            blockHash: BLOCK_HASH,
            btcTx: btcTransaction,
            // merkle branch values are fake, we don't need them for this test
            // to get actual values use https://github.com/FairgateLabs/rust-bitvmx-transactions/blob/main/src/bin/bridge-pmt.rs
            merkleBranchPath: 4285202432,
            merkleBranchHashes: new bytes32[](1)
        });
        pegInRequestTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.BridgeBtcTxInvalidMerkleBranch.selector,
                getExpectedPegInRequestTxHash(),
                pegInRequestTxSPVProof.merkleBranchPath,
                pegInRequestTxSPVProof.merkleBranchHashes
            )
        );
        // Act
        pm.registerPegInRequest(pegInRequestTxSPVProof);
    }

    // ========================== ACCEPT PEG IN ==========================
    function test_acceptPegInRequest_Revert_UnregisteredPegInRequest() external {
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPegInTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInAcceptedTxSPVProof = BtcTxSPVProof({
            blockHash: BLOCK_HASH,
            btcTx: btcTransaction,
            // merkle branch values are fake, we don't need them for this test
            // to get actual values use https://github.com/FairgateLabs/rust-bitvmx-transactions/blob/main/src/bin/bridge-pmt.rs
            merkleBranchPath: 4285202432,
            merkleBranchHashes: new bytes32[](1)
        });
        pegInAcceptedTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegManager.UnregisteredPegInRequest.selector, btcTransaction.inputs[0].txId)
        );

        // Act
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);
    }

    function test_acceptPegInRequest_Success() external {
        // ===  Before test setup  is run for this  test ===
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPegInTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInAcceptedTxSPVProof = BtcTxSPVProof({
            blockHash: BLOCK_HASH,
            btcTx: btcTransaction,
            // merkle branch values are fake, we don't need them for this test
            // to get actual values use https://github.com/FairgateLabs/rust-bitvmx-transactions/blob/main/src/bin/bridge-pmt.rs
            merkleBranchPath: 4285202432,
            merkleBranchHashes: new bytes32[](1)
        });
        pegInAcceptedTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectEmit(address(pm));

        // We emit the event we expect to see.
        bytes32 pegInRequestTxHash = pegInAcceptedTxSPVProof.btcTx.inputs[0].txId;
        bytes32 acceptPegInTxHash = getExpectedAcceptPegInTxHash();
        uint64 streamId = 0;
        uint64 slotId = 0;
        emit IPegManager.AcceptedPegInRequest(
            pegInAcceptedTxSPVProof.blockHash,
            acceptPegInTxHash,
            pegInRequestTxHash,
            0, //vout
            streamId,
            PACKET_NUMBER,
            slotId, //slotId
            RSK_DESTINATION_ADDRESS,
            satoshiToWei(btcTransaction.outputs[0].amount), // Rbtc amount
            btcTransaction.outputs[0].scriptPubKey
        );

        // Act
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);

        // Assert
        // Registered Peg In Stream Position
        StreamPosition memory streamPosition = pm.getPegInRequest(pegInRequestTxHash);
        assertEq(streamPosition.streamId, streamId, "Incorrect streamId registered");
        assertEq(streamPosition.packetNumber, PACKET_NUMBER, "Incorrect packetNumber registered");
        assertEq(streamPosition.slotId, 0, "Incorrect slotId registered");
        assertEq(uint256(streamPosition.pegStatus), uint256(PegStatus.ACCEPTED), "PegIn Request was not accepted");
        // Registered Peg In Temp info should be deleted
        RequestPegInTempInfo memory pegInTempInfo = pm.getRequestPegInTempInfo(pegInRequestTxHash);
        assertEq(pegInTempInfo.outputAmount, 0, "Peg in temp info outputAmount should be deleted");
        assertEq(
            pegInTempInfo.rskDestinationAddress, address(0), "Peg in temp info destinationAddress should be deleted"
        );
        assertEq(
            pegInTempInfo.btcReimbursementPubKey,
            bytes32(0),
            "Peg in temp info btcReimbursementPubKey should be deleted"
        );
        assertEq(pegInTempInfo.utxoScriptPubKey, hex"", "Peg in temp info utxoScriptPubKey should be deleted");
        // Registered Peg In Slot
        Slot memory slot = pm.getSlot(streamId, PACKET_NUMBER, slotId);
        assertEq(uint256(slot.state), uint256(SlotState.FILLED), "Slot should be filled");
        assertEq(slot.acceptPegInTx, acceptPegInTxHash, "Incorrect acceptPegInTx");
        assertEq(slot.acceptPegInAmount, btcTransaction.outputs[0].amount, "Incorrect acceptPegInAmount");
    }

    function test_acceptPegInRequest_Revert_AlreadyRegisteredAcceptPegIn() external {
        // ===  Before test setup  is run for this  test ===
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPegInTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInAcceptedTxSPVProof = BtcTxSPVProof({
            blockHash: BLOCK_HASH,
            btcTx: btcTransaction,
            // merkle branch values are fake, we don't need them for this test
            // to get actual values use https://github.com/FairgateLabs/rust-bitvmx-transactions/blob/main/src/bin/bridge-pmt.rs
            merkleBranchPath: 4285202432,
            merkleBranchHashes: new bytes32[](1)
        });
        pegInAcceptedTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Register First  Accept Peg In Request
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegManager.AlreadyRegisteredAcceptPegIn.selector, btcTransaction.inputs[0].txId)
        );

        // Act Register Second Accept Peg In Request
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);
    }

    function test_acceptPegInRequest_Revert_IncorrectInputsNumber() external {
        // ===  Before test setup  is run for this  test ===
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPegInTx();
        btcTransaction.inputs = new BtcTxIn[](0);
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInAcceptedTxSPVProof = BtcTxSPVProof({
            blockHash: BLOCK_HASH,
            btcTx: btcTransaction,
            // merkle branch values are fake, we don't need them for this test
            // to get actual values use https://github.com/FairgateLabs/rust-bitvmx-transactions/blob/main/src/bin/bridge-pmt.rs
            merkleBranchPath: 4285202432,
            merkleBranchHashes: new bytes32[](1)
        });
        pegInAcceptedTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegManager.IncorrectInputsNumber.selector, btcTransaction.inputs.length, 1)
        );

        // Act
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);
    }

    function test_acceptPegInRequest_Revert_IncorrectOutputsNumber() external {
        // ===  Before test setup  is run for this  test ===
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPegInTx();
        btcTransaction.outputs = new BtcTxOut[](0);
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInAcceptedTxSPVProof = BtcTxSPVProof({
            blockHash: BLOCK_HASH,
            btcTx: btcTransaction,
            // merkle branch values are fake, we don't need them for this test
            // to get actual values use https://github.com/FairgateLabs/rust-bitvmx-transactions/blob/main/src/bin/bridge-pmt.rs
            merkleBranchPath: 4285202432,
            merkleBranchHashes: new bytes32[](1)
        });
        pegInAcceptedTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegManager.IncorrectOutputsNumber.selector, btcTransaction.outputs.length, 2)
        );

        // Act
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);
    }

    function test_acceptPegInRequest_Revert_InvalidVout() external {
        // ===  Before test setup  is run for this  test ===
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPegInTx();
        btcTransaction.inputs[0].vout = 1;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInAcceptedTxSPVProof = BtcTxSPVProof({
            blockHash: BLOCK_HASH,
            btcTx: btcTransaction,
            // merkle branch values are fake, we don't need them for this test
            // to get actual values use https://github.com/FairgateLabs/rust-bitvmx-transactions/blob/main/src/bin/bridge-pmt.rs
            merkleBranchPath: 4285202432,
            merkleBranchHashes: new bytes32[](1)
        });
        pegInAcceptedTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegManager.InvalidVout.selector, btcTransaction.inputs[0].vout, 0));

        // Act
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);
    }

    function test_acceptPegInRequest_Revert_Revert_NotEnoughConfirmations() external {
        // ===  Before test setup  is run for this  test ===
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPegInTx();
        int256 actualConfirmations = 0;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Create PegIn struct information
        BtcTxSPVProof memory pegInAcceptedTxSPVProof = BtcTxSPVProof({
            blockHash: BLOCK_HASH,
            btcTx: btcTransaction,
            // merkle branch values are fake, we don't need them for this test
            // to get actual values use https://github.com/FairgateLabs/rust-bitvmx-transactions/blob/main/src/bin/bridge-pmt.rs
            merkleBranchPath: 4285202432,
            merkleBranchHashes: new bytes32[](1)
        });
        pegInAcceptedTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;
        Stream memory stream = pm.getStreamById(0);
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.NotEnoughConfirmations.selector, actualConfirmations, stream.pegInConfirmations
            )
        );

        // Act
        pm.acceptPegInRequest(pegInAcceptedTxSPVProof);
    }

    // ================= Request PegOut =================
    function test_computePegOutTxHash() external view {
        // Arrange
        bytes32 p2tr_spk = 0x9687ca13c4fb3fa3ba05c2f9119dda026bfe66f0098dcf9b896a98ecb2e96702;
        bytes memory usrPubKey = hex"027d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f";
        PrevoutData memory prevoutData = PrevoutData({
            txid: 0x8cc94a32480857817b037792eb95556670c9e001981f36102b72b96a8e559789,
            vout: 0,
            value: 9365,
            scriptPubKey: BtcTaproot.getP2TRScriptPubKey(p2tr_spk)
        });

        // The amount to be sent to the user
        uint64 amount = prevoutData.value - (SPEED_UP_AMOUNT + P2TR_FEES); // 0.00008730 BTC

        // Act
        (bytes32 result,) = pm.computePegOutTxHash(usrPubKey, prevoutData, amount, SPEED_UP_AMOUNT);

        // ExpectedHash hash computed externally from a run of the pegout flow of the protocol builder
        // using the following inputs and running on regtest
        // required inputs:
        // - usrPubKey = 027d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f
        // - prevoutsData = [
        //     {
        //         "txid": "8cc94a32480857817b037792eb95556670c9e001981f36102b72b96a8e559789",
        //         "vout": 0,
        //         "value": 9365,
        //         "scriptPubKey": P2TR script from (hex"0x9687ca13c4fb3fa3ba05c2f9119dda026bfe66f0098dcf9b896a98ecb2e96702")
        //     }
        // ]
        // - amount = 9365 - (300 + 335);
        bytes32 expectedHash = 0x78e1d97d2bae82ee61d183c20d612130e854f1254ef4f12455f29e3d8cc34872;

        // Assert
        assertEq(result, expectedHash, "Encoded data does not match expectedHash value");
    }

    function test_requestPegOut_Success() external {
        // Arrange
        bytes32 expectedHash = 0x2e2235c6c12f69f2eae6af9aa6e49f9f0176132e0fe28bda666d8d1a63d6cda2;
        bytes memory expectedDigest =
            hex"00010200000000000000234337e863e00e6ff45f167a14f3963bea912bc0d739c2b402d04f376e814ae2e247139cedddd1ee740814e7de2e771c3745091bbb7af21d4122087c8bc17a36a0c6dbc3091625a23fd870bf8d09182484c12fa63a5c29045a431cf445f153e523e9829bfb4e23fbd3c4848baa035af15d73bcb83e510f7f097f90a21a4280d2217f9b69543663eb9e09051daf2f4b82b1556c115496a4247808ccb85b846a6e0000000000";

        bytes memory usrPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        bytes32 txId = 0xb24858ade3e5be49ae63facb93524ddf460d0771f093525dae328b6c435516a2;
        bytes memory scriptPubKey = hex"02f519f51e435c20d38af683ea86862f4591ce8cda248077c2d9a72a76b62f32";

        uint64 amount = 10000000; // 0.1 BTC
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = pm.getStream(uint64(amount));
        uint64 packetNumber = 0;
        uint64 slotId = 0;

        pm.setSlotHarness(stream.streamId, packetNumber, slotId, SlotState.FILLED, scriptPubKey, txId, amount);

        // Assert
        vm.expectEmit(address(pm));
        emit IPegManager.PegOutRequested(
            usrPubKey, amount, expectedHash, expectedDigest, stream.streamId, packetNumber, slotId
        );

        // Act
        pm.requestPegOut{value: amountInWei}(usrPubKey, false);

        // Assert
        bytes32 result = pm.getPegOutTxHash(keccak256(abi.encodePacked(usrPubKey, amount)));
        assertEq(result, expectedHash, "expected hash doesn't match the pegout computed one");

        // Assert
        Slot memory slot = pm.getSlot(stream.streamId, packetNumber, slotId);
        assertEq(uint64(slot.state), uint64(SlotState.LOCKED), "Slot was not locked");
    }

    function test_requestPegOut_Revert_InvalidPublicKeyLength() external {
        // Arrange
        bytes memory usrPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b00";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegManager.InvalidPubKeyLength.selector, usrPubKey.length));

        // Act
        pm.requestPegOut(usrPubKey, false);
    }

    function test_requestPegOut_Revert_StreamNotFoundByDenomination() external {
        // Arrange
        bytes memory usrPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = 5;
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.StreamNotFoundByDenomination.selector, amount));

        // Act
        pm.requestPegOut{value: amountInWei}(usrPubKey, false);
    }

    function test_requestPegOut_Revert_NoFilledSlot() external {
        // Arrange
        bytes memory usrPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = 100000; // 0.1 BTC
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = pm.getStream(uint64(amount));
        uint64 packetNumber = 0;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.NoFilledSlot.selector, stream.streamId, packetNumber));

        // Act
        pm.requestPegOut{value: amountInWei}(usrPubKey, false);
    }

    function test_getFirstFilledSlot_Success() external {
        // Arrange
        pm.setSlotHarness(0, 0, 0, SlotState.FILLED, hex"00", 0, 0);

        // Act
        (Slot memory slot,) = pm.getFirstFilledSlot(0);
        assertEq(uint64(slot.state), uint64(SlotState.FILLED), "Incorrect slot state");
    }

    function test_getFirstFilledSlot_NoFilledSlot() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.NoFilledSlot.selector, 0, 0));

        // Act
        pm.getFirstFilledSlot(0);
    }
}
