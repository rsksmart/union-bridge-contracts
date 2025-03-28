// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {HelperContract} from "./helpers/HelperContract.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {
    BtcTxIn,
    BtcTxOut,
    BtcTransaction,
    IBitcoinManager,
    P2TR_FEES,
    SPEED_UP_AMOUNT
} from "src/interfaces/IBitcoinManager.sol";

contract TestBtcHelper is Test, HelperContract {
    function setUp() external {
        bitcoinManager = new BitcoinManager();
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

    // ========================== REGISTER PEG IN REQUEST ==========================
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

    function test_validatRequestPegInP2TROutput_Success() external {
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
        btcTxOut.amount = VALUE - P2TR_FEES;
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

    function test_validateAcceptPegInP2TROutput_Success() external {
        // Arrange
        BtcTxOut memory btcTxOut = getBtcAcceptPegInTx().outputs[0];
        uint64 value = VALUE;
        address rskDestinationAddress = getPegInRskDestinationAddress();
        bytes32 committeePubKey = COMMITEE_1_PUB_KEY;
        // Act
        bitcoinManager.validateAcceptPegInP2TROutput(committeePubKey, value, btcTxOut);
        // Assert if not reverts everything is ok
    }

    function test_validateAcceptPegInP2TROutput_Revert_InvalidOutputAmount() external {
        // Arrange
        BtcTxOut memory btcTxOut = getBtcAcceptPegInTx().outputs[0];
        btcTxOut.amount = VALUE - (P2TR_FEES + SPEED_UP_AMOUNT + 1);
        bytes32 committeePubKey = COMMITEE_1_PUB_KEY;
        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                IBitcoinManager.InvalidOutputAmount.selector, btcTxOut.amount, VALUE - (P2TR_FEES + SPEED_UP_AMOUNT)
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

    function test_validateSpeedUpOutput_Success() external {
        // Arrange
        BtcTxOut memory btcTxOut = getBtcSpeedUpOut();
        bytes32 committeePubKey = COMMITEE_1_PUB_KEY;
        // Act
        bitcoinManager.validateSpeedUpOutput(committeePubKey, btcTxOut);
        // Assert if not reverts everything is ok
    }

    function test_validateSpeedUpOutput_Revert_InvalidOutputAmount() external {
        // Arrange
        BtcTxOut memory btcTxOut = getBtcSpeedUpOut();
        btcTxOut.amount = SPEED_UP_AMOUNT - 1;
        bytes32 committeePubKey = COMMITEE_1_PUB_KEY;
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IBitcoinManager.InvalidValue.selector, btcTxOut.amount, SPEED_UP_AMOUNT));
        // Act
        bitcoinManager.validateSpeedUpOutput(committeePubKey, btcTxOut);
    }

    function test_validateSpeedUpOutput_Revert_IncorrectOutputScript() external {
        // Arrange
        BtcTxOut memory btcTxOut = getBtcSpeedUpOut();
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
        bitcoinManager.validateSpeedUpOutput(committeePubKey, btcTxOut);
    }
}
