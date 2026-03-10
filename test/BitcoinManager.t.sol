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
import {Constants} from "src/libraries/Constants.sol";
import {BtcTaproot} from "src/libraries/BtcTaproot.sol";
import {BtcScriptParser} from "src/libraries/BtcScriptParser.sol";

contract BitcoinManagerTest is Test, HelperContract {
    function setUp() external {
        runTestDeployScript();

        // Creating a committee is required for getRequestPeginEnablerOut which needs committee dispute keys
        setup_completeCommittee();
    }

    function test_getTemporaryPeginAddress_Success() external view {
        // Arrange
        address rskAddress = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
        uint64 value = 100_000; // 0.001 BTC
        bytes32 btcReimbursementPubKey = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
        bytes memory committeePubKey =
            abi.encodePacked(bytes1(0x02), bytes32(0xd1cfc2049322ff6ba3a88c6e17c6622308f0fb1d2910ffadb309e4116358723d));
        uint32 timelockBlocks = 1;
        // Act
        string memory result = bitcoinManager.getTemporaryPeginAddress(
            timelockBlocks, rskAddress, value, btcReimbursementPubKey, committeePubKey
        );
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
        uint32 timelockBlocks = 1;

        // Act
        string memory result = bitcoinManager.getTemporaryPeginAddress(
            timelockBlocks, rskAddress, value, btcReimbursementPubKey, committeePubKey
        );

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
        uint32 timelockBlocks = 1;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IBitcoinManager.InvalidCommitteePublicKeyLength.selector, 0, 33));

        // Act
        bitcoinManager.getTemporaryPeginAddress(
            timelockBlocks, rskAddress, value, btcReimbursementPubKey, committeePubKey
        );
    }

    function test_getTemporaryPeginAddress_Revert_InvalidCommitteePublicKeyZero() external {
        // Arrange
        address rskAddress = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
        uint64 value = 100_000; // 0.001 BTC
        bytes32 btcReimbursementPubKey = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
        bytes memory committeePubKey = new bytes(33); // All zeros, 33 bytes
        uint32 timelockBlocks = 1;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IBitcoinManager.InvalidCommitteePublicKeyZero.selector));

        // Act
        bitcoinManager.getTemporaryPeginAddress(
            timelockBlocks, rskAddress, value, btcReimbursementPubKey, committeePubKey
        );
    }

    function test_getBtcTxid_Success() external {
        // Arrange
        (BtcTransaction memory btcTx,) = getBtcRequestPeginTx();
        // Act
        bytes32 txid = bitcoinManager.getBtcTxid(btcTx);
        // Assert
        assertEq(
            txid,
            getBtcTxid(btcTx),
            "Hashing the Transaction without the witness with Hash256 should give the correct txId"
        );
    }

    function test_getBtcTxid_requestPegin_Success() external view {
        // Arrange
        BtcTransaction memory btcTx =
            BtcTransaction({version: 2, inputs: new BtcTxIn[](1), outputs: new BtcTxOut[](2), locktime: 0});
        btcTx.inputs[0] = BtcTxIn({
            txId: 0xab4fc20be47cf3d862da4d9a477b3d5d0e0f3b1e54ce220e34646e7f7550f99c,
            vout: 0,
            sequence: Constants.SEQUENCE,
            scriptSig: hex""
        });
        btcTx.outputs[0] = BtcTxOut({
            amount: 100000,
            scriptPubKey: hex"5120705364e5015f051b3c85957d8e2c581c17318b50156a68c333739720d388ddfc"
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
            0x032aba885f5456d794ae371d7e541eea9104d86dd6e93b5ee10da0d943efe61e,
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
            getRequestPeginOpReturnOut(packetNumber, rskDestinationAddress, btcReimbursementPubKey);
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

        (BtcTransaction memory btcTx,) = getBtcRequestPeginTx();
        BtcTxOut memory btcTxOut = btcTx.outputs[0];
        uint64 value = VALUE;
        address rskDestinationAddress = getPeginRskDestinationAddress();
        bytes32 btcReimbursementPubKey = getPeginBtcReimbursementPubKey();
        bytes memory committeePubKey = COMMITTEE_TAKE_PUB_KEY();
        uint32 timelockBlocks = 12;
        // Act
        vm.prank(address(peginManager));
        bitcoinManager.validateRequestPeginP2TROutput(
            timelockBlocks, rskDestinationAddress, value, btcReimbursementPubKey, committeePubKey, btcTxOut
        );
        // Assert if not reverts everything is ok
    }

    function test_validateRequestPeginP2TROutput_Revert_InvalidOutputAmount() external {
        // Arrange
        (BtcTransaction memory btcTx,) = getBtcRequestPeginTx();
        BtcTxOut memory btcTxOut = btcTx.outputs[0];
        btcTxOut.amount = VALUE - Constants.P2TR_FEE;
        uint64 value = VALUE;
        address rskDestinationAddress = getPeginRskDestinationAddress();
        bytes32 btcReimbursementPubKey = getPeginBtcReimbursementPubKey();
        bytes memory committeePubKey = COMMITTEE_TAKE_PUB_KEY();
        uint32 timelockBlocks = 1;
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IBitcoinManager.InvalidOutputAmount.selector, btcTxOut.amount, value));
        // Act
        vm.prank(address(peginManager));
        bitcoinManager.validateRequestPeginP2TROutput(
            timelockBlocks, rskDestinationAddress, value, btcReimbursementPubKey, committeePubKey, btcTxOut
        );
    }

    function test_getEnablerOutputP2TRScriptPub_Success() external view {
        // Arrange
        bytes memory committeePubKey = hex"02d1cfc2049322ff6ba3a88c6e17c6622308f0fb1d2910ffadb309e4116358723d";

        // Hardcoded dispute keys from the test committee (10 members)
        bytes32[] memory disputeKeys = new bytes32[](10);
        disputeKeys[0] = 0x186ba6bc992e556294d75dcf0b60cbea88d3de0bae02cf4401e97d2fbfdca40d;
        disputeKeys[1] = 0xb40e85efe8651cd63b9514adac7fcca825484acb6841ee80867fcaa7d41156c6;
        disputeKeys[2] = 0x58b91a3800e0cd15d0acb64b5aad901043a62ca82862b8f0a97ff5e2de50af6c;
        disputeKeys[3] = 0x8a8240d1ff88b42c53e5cf1d3093a9589277b0e8e413712599d0ef2a5a32c04b;
        disputeKeys[4] = 0x2e6ec7e4985bca96582f7474eef4c7ebb6552b066c60c8e2d4ded3b8d56f9060;
        disputeKeys[5] = 0x924b3bf87fc171eade0db2940235b89bb714776b0e833652377d7e93be52d8cd;
        disputeKeys[6] = 0xda48fd2a49e1d997c456c4fb1c5075b0d4a3cc733a18eda2eac650d4fa1636bd;
        disputeKeys[7] = 0xf8935fcdc39fc07d8decedeab6fc2fefd7059a754e223aff6f028303b86239a8;
        disputeKeys[8] = 0x99696efd85605ae9c7e1486a6ee8ed074122afd6be8f7ac1b41db5a14b96dafd;
        disputeKeys[9] = 0xe711328b222907a4428b24e7624117257415082694a0aa23bd52fdafe1f54536;

        // Expected P2TR scriptPubKey generated from the committee pubkey and dispute keys
        bytes memory expectedScript = hex"51201cbeafdb8fa122bf71ea817df2ed9131bfa165952d63ba5841313f918a0f86c9";

        // Act
        bytes memory script = bitcoinManager.getEnablerOutputP2TRScriptPub(committeePubKey, disputeKeys);

        // Assert
        // P2TR scriptPubKey should be 34 bytes: OP_1 (0x51) + OP_PUSHBYTES_32 (0x20) + 32 bytes witness program
        assertEq(script.length, 34, "P2TR script should be 34 bytes");
        assertEq(uint8(script[0]), 0x51, "First byte should be OP_1");
        assertEq(uint8(script[1]), 0x20, "Second byte should be OP_PUSHBYTES_32");

        // Verify it matches the expected output
        assertEq(script, expectedScript, "Script should match expected P2TR output");
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
        BtcTxOut memory btcTxOut = getUserSpeedUpOut();
        bytes32 speedUpPubKey = BTC_REIMBURSEMENT_PUBKEY;
        // Act
        bitcoinManager.validateSpeedUpOutput(speedUpPubKey, btcTxOut);
        // Assert if not reverts everything is ok
    }

    function test_validateSpeedUpOutput_Revert_InvalidOutputAmount() external {
        // Arrange
        BtcTxOut memory btcTxOut = getUserSpeedUpOut();
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
        BtcTxOut memory btcTxOut = getUserSpeedUpOut();
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
        // Prepare prevout data for both inputs: taptree and enabler outputs
        PrevoutData[] memory prevoutDatas = new PrevoutData[](2);
        prevoutDatas[0] = PrevoutData({
            // txid: 0x8cc94a32480857817b037792eb95556670c9e001981f36102b72b96a8e559789,
            // vout: 0,
            value: 9365,
            scriptPubKey: BtcTaproot.getP2TRScriptPubKey(p2tr_spk)
        });
        // Mock enabler output - using simple script for testing
        prevoutDatas[1] = PrevoutData({
            value: Constants.SPEED_UP_AMOUNT,
            scriptPubKey: BtcTaproot.getP2TRScriptPubKey(p2tr_spk) // Using same script for simplicity in test
        });

        // The amount to be sent to the user
        // prevoutDatas[0].value - (Constants.SPEED_UP_AMOUNT + Constants.P2TR_FEE); // 0.00008730 BTC

        // Act
        BitcoinSignatureData memory pegoutData = bitcoinManager.getPegoutTxData(userPubKey, acceptPeginTx, prevoutDatas);
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
        bytes32 expectedHash = 0x5bf6a18f4e077624f52731dc49f21c17951f80e0a73a75c1273cf4ce5ddb6b2e;

        // Assert
        assertEq(result, expectedHash, "Encoded data does not match expectedHash value");
    }

    function test_validatePegoutIdOutput_Success() external view {
        // Arrange
        bytes32 expectedPegoutId = hex"abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdef";
        bytes memory pegoutIdScript = BtcScriptParser.getPegoutIdScript(expectedPegoutId);
        BtcTxOut memory btcTxOut = BtcTxOut({amount: 10000, scriptPubKey: pegoutIdScript});

        // Act
        bitcoinManager.validatePegoutIdOutput(btcTxOut, expectedPegoutId);
        // Assert if not reverts everything is ok
    }

    function test_validatePegoutIdOutput_Revert_IncorrectOutputScript() external {
        // Arrange
        bytes32 expectedPegoutId = hex"abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdef";
        bytes memory pegoutIdScript = BtcScriptParser.getPegoutIdScript(expectedPegoutId);
        BtcTxOut memory btcTxOut = BtcTxOut({amount: 10000, scriptPubKey: pegoutIdScript});

        bytes32 differentPegoutId = hex"123456123456123456123456123456123456123456123456";
        bytes memory differentPegoutIdScript = BtcScriptParser.getPegoutIdScript(differentPegoutId);

        // Assert
        vm.assertNotEq(expectedPegoutId, differentPegoutId, "Test setup error: pegout IDs should be different");

        vm.expectRevert(
            abi.encodeWithSelector(
                IBitcoinManager.IncorrectOutputScript.selector, pegoutIdScript, differentPegoutIdScript
            )
        );

        // Act
        bitcoinManager.validatePegoutIdOutput(btcTxOut, differentPegoutId);
    }
}
