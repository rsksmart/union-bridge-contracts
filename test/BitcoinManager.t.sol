// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {HelperContract} from "./helpers/HelperContract.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {BtcTxIn, BtcTxOut, BtcTransaction, IBitcoinManager, PrevoutData} from "src/interfaces/IBitcoinManager.sol";
import {OpCodes} from "src/libraries/OpCodes.sol";
import {Constants} from "src/libraries/Constants.sol";
import {BtcTaproot} from "src/libraries/BtcTaproot.sol";

contract TestBtcHelper is Test, HelperContract {
    function setUp() external {
        runTestDeployScript();
    }

    function test_getTemporaryPegInAddress_Success() external view {
        // Arrange
        address rskAddress = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
        uint64 value = 100_000; // 0.001 BTC
        bytes32 btcReimbursementPubKey = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
        bytes32 committeePubKey = 0xd1cfc2049322ff6ba3a88c6e17c6622308f0fb1d2910ffadb309e4116358723d;
        // Act
        string memory result =
            bitcoinManager.getTemporaryPegInAddress(rskAddress, value, btcReimbursementPubKey, committeePubKey);
        // Assert
        string memory expectedAddress = "bcrt1py28js8ef0lgpe5mrh8yn7apt52tkc8k95cyrm8m4fjmpu5zn2mps7esu9h";
        assertEq(result, expectedAddress, "Incorrect temporary peg in address at BitcoinManager");
    }

    function test_getBtcTxHash_Success() external view {
        // Arrange
        BtcTransaction memory btcTx = getBtcPegInRequestTx();
        // Act
        bytes32 txHash = bitcoinManager.getBtcTxHash(btcTx);
        // Assert
        assertEq(
            txHash,
            getExpectedPegInRequestTxHash(),
            "Hashing the Transaction without the witness with Hash256 should give the correct txId"
        );
    }

    function test_getBtcTxHash_pegInRequest_Success() external view {
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
            scriptPubKey: hex"5120228f281f297fd01cd363b9c93f742ba2976c1ec5a6083d9f754cb61e505356c3"
        });
        btcTx.outputs[1] = BtcTxOut({
            amount: 0,
            scriptPubKey: hex"6a4552534b5f504547494e00000000000000007ac5496aee77c1ba1f0854206a26dda82a81d6d87d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f"
        });
        // Act
        bytes32 txHash = bitcoinManager.getBtcTxHash(btcTx);
        // Assert
        assertEq(
            txHash,
            0x7b160254c1f59d16a1d8c18c89fadb875a0a8cfc94758a76ad6b9caaf21b146d,
            "Hashing the Transaction without the witness with Hash256 didn't give the correct txId"
        );
    }

    // ========================== REGISTER PEG IN REQUEST ==========================
    function test_getPegInRequestP2TRScriptPub_Success() external view {
        // Arrange
        address rskDestinationAddress = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
        uint64 value = 100_000;
        bytes32 btcReimbursementPubKey = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
        bytes32 committeePubKey = 0xd1cfc2049322ff6ba3a88c6e17c6622308f0fb1d2910ffadb309e4116358723d;
        // Act
        bytes memory scriptPubKey = bitcoinManager.getPegInRequestP2TRScriptPub(
            rskDestinationAddress, value, btcReimbursementPubKey, committeePubKey
        );
        // Assert
        assertEq(
            scriptPubKey,
            abi.encodePacked(
                OpCodes.OP_1,
                OpCodes.OP_PUSHBYTES_32,
                bytes32(0x228f281f297fd01cd363b9c93f742ba2976c1ec5a6083d9f754cb61e505356c3)
            ),
            "The script pub key should be correct at BitcoinManager"
        );
    }

    function test_getPegInOpReturnData_Success() external view {
        // Arrange
        BtcTxOut memory btcTxOut = getPegInRequestOpReturnOut();
        // Act
        (uint64 packetNumber, address rskDestinationAddress, bytes32 btcReimbursementPubKey) =
            bitcoinManager.getPegInOpReturnData(btcTxOut);
        // Assert
        assertEq(packetNumber, getPegInRequestPacket(), "OP_RETURN packet number should be correct  ");
        assertEq(
            rskDestinationAddress,
            getPegInRskDestinationAddress(),
            "OP_RETURN RSK destination address should be correct"
        );
        assertEq(
            btcReimbursementPubKey,
            getPegInBtcReimbursementPubKey(),
            "OP_RETURN BTC reimbursement public key should be correct"
        );
    }

    function test_validatRequestPegInP2TROutput_Success() external view {
        // Arrange
        BtcTxOut memory btcTxOut = getBtcPegInRequestTx().outputs[0];
        uint64 value = VALUE;
        address rskDestinationAddress = getPegInRskDestinationAddress();
        bytes32 btcReimbursementPubKey = getPegInBtcReimbursementPubKey();
        bytes32 committeePubKey = COMMITEE_1_PUB_KEY;
        // Act
        bitcoinManager.validatRequestPegInP2TROutput(
            rskDestinationAddress, value, btcReimbursementPubKey, committeePubKey, btcTxOut
        );
        // Assert if not reverts everything is ok
    }

    function test_validatRequestPegInP2TROutput_Revert_InvalidOutputAmount() external {
        // Arrange
        BtcTxOut memory btcTxOut = getBtcPegInRequestTx().outputs[0];
        btcTxOut.amount = VALUE - Constants.P2TR_FEE;
        uint64 value = VALUE;
        address rskDestinationAddress = getPegInRskDestinationAddress();
        bytes32 btcReimbursementPubKey = getPegInBtcReimbursementPubKey();
        bytes32 committeePubKey = COMMITEE_1_PUB_KEY;
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IBitcoinManager.InvalidOutputAmount.selector, btcTxOut.amount, value));
        // Act
        bitcoinManager.validatRequestPegInP2TROutput(
            rskDestinationAddress, value, btcReimbursementPubKey, committeePubKey, btcTxOut
        );
    }

    // ========================== REGISTER ACCEPT PEG IN ==========================

    function test_validateAcceptPegInP2TROutput_Success() external view {
        // Arrange
        BtcTxOut memory btcTxOut = getBtcAcceptPegInTx().outputs[0];
        uint64 value = VALUE;
        bytes32 committeePubKey = COMMITEE_1_PUB_KEY;
        // Act
        bitcoinManager.validateAcceptPegInP2TROutput(committeePubKey, value, btcTxOut);
        // Assert if not reverts everything is ok
    }

    function test_validateAcceptPegInP2TROutput_Revert_InvalidOutputAmount() external {
        // Arrange
        BtcTxOut memory btcTxOut = getBtcAcceptPegInTx().outputs[0];
        btcTxOut.amount = VALUE - (Constants.P2TR_FEE + Constants.SPEED_UP_AMOUNT + 1);
        bytes32 committeePubKey = COMMITEE_1_PUB_KEY;
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IBitcoinManager.InvalidOutputAmount.selector,
                btcTxOut.amount,
                VALUE - (Constants.P2TR_FEE + Constants.SPEED_UP_AMOUNT)
            )
        );
        // Act
        bitcoinManager.validateAcceptPegInP2TROutput(committeePubKey, VALUE, btcTxOut);
    }

    function test_validateAcceptPegInP2TROutput_Revert_IncorrectOutputScript() external {
        // Arrange
        BtcTxOut memory btcTxOut = getBtcAcceptPegInTx().outputs[0];
        bytes memory expectedScriptPubKey = btcTxOut.scriptPubKey;
        btcTxOut.scriptPubKey = hex"0014d3b4045c40a133ee361f766ceae4d82398fc5058";
        bytes32 committeePubKey = COMMITEE_1_PUB_KEY;
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IBitcoinManager.IncorrectOutputScript.selector, btcTxOut.scriptPubKey, expectedScriptPubKey
            )
        );
        // Act
        bitcoinManager.validateAcceptPegInP2TROutput(committeePubKey, VALUE, btcTxOut);
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
    function test_getPegOutSignatureHash_Success() external view {
        // Arrange
        bytes32 p2tr_spk = 0x9687ca13c4fb3fa3ba05c2f9119dda026bfe66f0098dcf9b896a98ecb2e96702;
        bytes memory usrPubKey = hex"027d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f";
        bytes32 acceptPegInTx = 0x8cc94a32480857817b037792eb95556670c9e001981f36102b72b96a8e559789;
        PrevoutData memory prevoutData = PrevoutData({
            // txid: 0x8cc94a32480857817b037792eb95556670c9e001981f36102b72b96a8e559789,
            // vout: 0,
            value: 9365,
            scriptPubKey: BtcTaproot.getP2TRScriptPubKey(p2tr_spk)
        });

        // The amount to be sent to the user
        // prevoutData.value - (Constants.SPEED_UP_AMOUNT + Constants.P2TR_FEE); // 0.00008730 BTC

        // Act
        (bytes32 result,) = bitcoinManager.getPegOutSignatureHash(usrPubKey, acceptPegInTx, prevoutData);

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
}
