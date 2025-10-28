// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HelperContract} from "./helpers/HelperContract.sol";
import {
    BtcTxIn,
    BtcTxOut,
    BtcTransaction,
    IBitcoinManager,
    PrevoutData,
    BitcoinSignatureData
} from "src/interfaces/IBitcoinManager.sol";
import {IPegManager} from "src/interfaces/IPegManager.sol";
import {Constants} from "src/libraries/Constants.sol";
import {BtcTaproot} from "src/libraries/BtcTaproot.sol";
import {BtcScriptParser} from "src/libraries/BtcScriptParser.sol";

contract TestBtcHelper is Test, HelperContract {
    function setUp() external {
        runTestDeployScript();
    }

    function test_getTemporaryPeginAddress_Success() external view {
        // Arrange
        address rskAddress = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
        uint64 value = 100_000; // 0.001 BTC
        bytes32 btcReimbursementPubKey = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
        bytes memory committeePubKey =
            abi.encodePacked(bytes1(0x02), bytes32(0xd1cfc2049322ff6ba3a88c6e17c6622308f0fb1d2910ffadb309e4116358723d));
        // Act
        string memory result =
            bitcoinManager.getTemporaryPeginAddress(rskAddress, value, btcReimbursementPubKey, committeePubKey);
        // Assert
        string memory expectedAddress = "bcrt1pff4szccvny97tn5d5q9xf5kw30p9njxnvd6q0tmp8f7tk8adphuqnxt4tt";
        assertEq(result, expectedAddress, "Incorrect temporary peg in address at BitcoinManager");
    }

    function test_getTemporaryPeginAddress_Success_DifferentAmountGivesDifferentAddress() external view {
        // Arrange
        address rskAddress = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
        uint64 value = 1_000_000; // 0.01 BTC
        bytes32 btcReimbursementPubKey = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
        bytes memory committeePubKey =
            abi.encodePacked(bytes1(0x02), bytes32(0xd1cfc2049322ff6ba3a88c6e17c6622308f0fb1d2910ffadb309e4116358723d));
        // Act
        string memory result =
            bitcoinManager.getTemporaryPeginAddress(rskAddress, value, btcReimbursementPubKey, committeePubKey);
        // Assert
        string memory expectedAddress = "bcrt1p9hdr74xdg69a7w6r4pfsrrnj3l7ku54x5jdmtwf4thnjyhkmeuhs79pnrw";
        assertEq(result, expectedAddress, "Incorrect temporary peg in address at BitcoinManager");
    }

    function test_getTemporaryPeginAddress_Revert_InvalidCommitteePublicKeyLength() external {
        // Arrange
        address rskAddress = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
        uint64 value = 100_000; // 0.001 BTC
        bytes32 btcReimbursementPubKey = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
        bytes memory committeePubKey = new bytes(0); // Invalid length (0 bytes)

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IBitcoinManager.InvalidCommitteePublicKeyLength.selector, 0, 33));

        // Act
        bitcoinManager.getTemporaryPeginAddress(rskAddress, value, btcReimbursementPubKey, committeePubKey);
    }

    function test_getTemporaryPeginAddress_Revert_InvalidCommitteePublicKeyZero() external {
        // Arrange
        address rskAddress = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
        uint64 value = 100_000; // 0.001 BTC
        bytes32 btcReimbursementPubKey = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
        bytes memory committeePubKey = new bytes(33); // All zeros, 33 bytes

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IBitcoinManager.InvalidCommitteePublicKeyZero.selector));

        // Act
        bitcoinManager.getTemporaryPeginAddress(rskAddress, value, btcReimbursementPubKey, committeePubKey);
    }

    function test_getBtcTxid_Success() external {
        // Arrange
        BtcTransaction memory btcTx = getBtcPeginRequestTx();
        // Act
        bytes32 txid = bitcoinManager.getBtcTxid(btcTx);
        // Assert
        assertEq(
            txid,
            getBtcTxid(btcTx),
            "Hashing the Transaction without the witness with Hash256 should give the correct txId"
        );
    }

    function test_getBtcTxid_peginRequest_Success() external view {
        // Arrange
        BtcTransaction memory btcTx =
            BtcTransaction({version: 2, inputs: new BtcTxIn[](1), outputs: new BtcTxOut[](2), locktime: 0});
        btcTx.inputs[0] = BtcTxIn({
            txId: 0xab4fc20be47cf3d862da4d9a477b3d5d0e0f3b1e54ce220e34646e7f7550f99c,
            vout: 0,
            sequence: 0xfffffffd,
            scriptSig: hex""
        });
        btcTx.outputs[0] = BtcTxOut({
            amount: 100000,
            scriptPubKey: hex"51202dda3f54cd468bdf3b43a853018e728ffd6e52a6a49bb5b9355de7225edbcf2f"
        });
        btcTx.outputs[1] = BtcTxOut({
            amount: 0,
            scriptPubKey: hex"6a4552534b5f504547494e00000000000000007ac5496aee77c1ba1f0854206a26dda82a81d6d87d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f"
        });
        // Act
        bytes32 txid = bitcoinManager.getBtcTxid(btcTx);
        // Assert
        assertEq(
            txid,
            0x3e2dae98db783476cc24e8fea4c7b6fdbfc6c211d576ab835ccf0c1e4e36f8f9,
            "Hashing the Transaction without the witness with Hash256 didn't give the correct txId"
        );
    }

    // ========================== REGISTER PEG IN REQUEST ==========================
    function test_getPeginOpReturnData_Success() external view {
        // Arrange
        uint64 packetNumber = 1; //using 1 because 0 would not test for endianess
        address rskDestinationAddress = getPeginRskDestinationAddress();
        bytes32 btcReimbursementPubKey = getPeginBtcReimbursementPubKey();
        BtcTxOut memory btcTxOut =
            getPeginRequestOpReturnOut(packetNumber, rskDestinationAddress, btcReimbursementPubKey);
        // Act
        (uint64 resPacketNumber, address resRskDestinationAddress, bytes32 resBtcReimbursementPubKey) =
            bitcoinManager.getPeginOpReturnData(btcTxOut);
        // Assert
        assertEq(packetNumber, resPacketNumber, "OP_RETURN parsed packet number does not match the expected");
        assertEq(
            rskDestinationAddress,
            resRskDestinationAddress,
            "OP_RETURN parsed RSK destination address does not match the expected"
        );
        assertEq(
            btcReimbursementPubKey,
            resBtcReimbursementPubKey,
            "OP_RETURN parsed BTC reimbursement public key does not match the expected"
        );
    }

    function test_validateRequestPeginP2TROutput_Success() external {
        // Arrange
        BtcTxOut memory btcTxOut = getBtcPeginRequestTx().outputs[0];
        uint64 value = VALUE;
        address rskDestinationAddress = getPeginRskDestinationAddress();
        bytes32 btcReimbursementPubKey = getPeginBtcReimbursementPubKey();
        bytes memory committeePubKey = COMMITTEE_PUB_KEY();
        // Act
        vm.prank(address(pm));
        bitcoinManager.validateRequestPeginP2TROutput(
            rskDestinationAddress, value, btcReimbursementPubKey, committeePubKey, btcTxOut
        );
        // Assert if not reverts everything is ok
    }

    function test_validateRequestPeginP2TROutput_Revert_InvalidOutputAmount() external {
        // Arrange
        BtcTxOut memory btcTxOut = getBtcPeginRequestTx().outputs[0];
        btcTxOut.amount = VALUE - Constants.P2TR_FEE;
        uint64 value = VALUE;
        address rskDestinationAddress = getPeginRskDestinationAddress();
        bytes32 btcReimbursementPubKey = getPeginBtcReimbursementPubKey();
        bytes memory committeePubKey = COMMITTEE_PUB_KEY();
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IBitcoinManager.InvalidOutputAmount.selector, btcTxOut.amount, value));
        // Act
        vm.prank(address(pm));
        bitcoinManager.validateRequestPeginP2TROutput(
            rskDestinationAddress, value, btcReimbursementPubKey, committeePubKey, btcTxOut
        );
    }

    // ========================== REGISTER ACCEPT PEG IN ==========================
    function test_getSpeedUpScriptPub_Success() external {
        // Arrange
        bytes32 pubKey = generatePubKey(1);
        // Act
        bytes memory script = bitcoinManager.getSpeedUpScriptPub(pubKey);
        // Assert
        assertEq(
            script,
            BtcScriptParser.getP2WPKHScript(abi.encodePacked(uint8(0x02), pubKey)),
            "getSpeedUpScriptPub should be correct"
        );
    }

    function test_validateSpeedUpOutput_Success() external view {
        // Arrange
        BtcTxOut memory btcTxOut = getBtcSpeedUpOut();
        bytes32 speedUpPubKey = BTC_REIMBURSEMENT_PUBKEY;
        // Act
        bitcoinManager.validateSpeedUpOutput(speedUpPubKey, btcTxOut);
        // Assert if not reverts everything is ok
    }

    function test_validateSpeedUpOutput_Revert_InvalidOutputAmount() external {
        // Arrange
        BtcTxOut memory btcTxOut = getBtcSpeedUpOut();
        btcTxOut.amount = Constants.SPEED_UP_AMOUNT - 1;
        bytes32 speedUpPubKey = BTC_REIMBURSEMENT_PUBKEY;
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IBitcoinManager.InvalidValue.selector, btcTxOut.amount, Constants.SPEED_UP_AMOUNT)
        );
        // Act
        bitcoinManager.validateSpeedUpOutput(speedUpPubKey, btcTxOut);
    }

    function test_validateSpeedUpOutput_Revert_IncorrectOutputScript() external {
        // Arrange
        BtcTxOut memory btcTxOut = getBtcSpeedUpOut();
        bytes memory expectedScriptPubKey = btcTxOut.scriptPubKey;
        btcTxOut.scriptPubKey = hex"0014d3b4045c40a133ee361f766ceae4d82398fc5058";
        bytes32 speedUpPubKey = BTC_REIMBURSEMENT_PUBKEY;
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IBitcoinManager.IncorrectOutputScript.selector, btcTxOut.scriptPubKey, expectedScriptPubKey
            )
        );
        // Act
        bitcoinManager.validateSpeedUpOutput(speedUpPubKey, btcTxOut);
    }

    // ========================== REGISTER PEG OUT ==========================
    function test_getPegoutTxData_Success() external view {
        // Arrange
        bytes32 p2tr_spk = 0x9687ca13c4fb3fa3ba05c2f9119dda026bfe66f0098dcf9b896a98ecb2e96702;
        bytes memory userPubKey = hex"027d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f";
        bytes32 acceptPeginTx = 0x8cc94a32480857817b037792eb95556670c9e001981f36102b72b96a8e559789;
        PrevoutData memory prevoutData = PrevoutData({
            // txid: 0x8cc94a32480857817b037792eb95556670c9e001981f36102b72b96a8e559789,
            // vout: 0,
            value: 9365,
            scriptPubKey: BtcTaproot.getP2TRScriptPubKey(p2tr_spk)
        });

        // The amount to be sent to the user
        // prevoutData.value - (Constants.SPEED_UP_AMOUNT + Constants.P2TR_FEE); // 0.00008730 BTC

        // Act
        BitcoinSignatureData memory pegoutData = bitcoinManager.getPegoutTxData(userPubKey, acceptPeginTx, prevoutData);
        bytes32 result = pegoutData.signatureHash;

        // ExpectedHash hash computed externally from a run of the pegout flow of the protocol builder
        // using the following inputs and running on regtest
        // required inputs:
        // - userPubKey = 027d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f
        // - prevoutsData = [
        //     {
        //         "txid": "8cc94a32480857817b037792eb95556670c9e001981f36102b72b96a8e559789",
        //         "vout": 0,
        //         "value": 9365,
        //         "scriptPubKey": P2TR script from (hex"0x9687ca13c4fb3fa3ba05c2f9119dda026bfe66f0098dcf9b896a98ecb2e96702")
        //     }
        // ]
        // - amount = 9365 - (540 + 335);
        bytes32 expectedHash = 0x827d50165346809719d5da8e3ef29b3e91b586648aee5846fc32e7714a117d0a;

        // Assert
        assertEq(result, expectedHash, "Encoded data does not match expectedHash value");
    }

    // ========================== PEG MANAGER SETTER ==========================
    function test_setPegManager_EmitsPegManagerUpdatedEvent() external {
        // Arrange
        address newPegManager = address(0x1234567890123456789012345678901234567890);

        // Act & Assert
        vm.expectEmit(address(bitcoinManager));
        emit IBitcoinManager.PegManagerUpdated(newPegManager);
        vm.prank(bitcoinManager.owner());
        bitcoinManager.setPegManager(IPegManager(newPegManager));
    }

    function test_setPegManager_Revert_InvalidZeroAddress() external {
        // Arrange
        address zeroAddress = address(0);
        vm.prank(bitcoinManager.owner());
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IBitcoinManager.InvalidZeroAddress.selector));
        // Act
        bitcoinManager.setPegManager(IPegManager(zeroAddress));
    }
}
