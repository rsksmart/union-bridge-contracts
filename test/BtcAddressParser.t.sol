// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {BtcAddressParser} from "src/libraries/BtcAddressParser.sol";

contract TestBtcAddressParser is Test {
    function setUp() external {}

    function test_getP2TRScriptPubKey_Success_KeyPath() external pure {
        // Arrenge
        bytes32 publicKey = 0x0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb;
        bytes32 merkleRoot = bytes32(0);
        // Act
        bytes memory scriptPubKey = BtcAddressParser.getP2TRScriptPubKey(publicKey, merkleRoot);
        // Assert
        assertEq(
            scriptPubKey,
            hex"5120f8bc2bbb52031daee28da58481e8ec3b045202ed9213b62bf33e221d31b3e6ef",
            "getP2TRScriptPubKey KeyPath should give the correct Script public key"
        );
    }

    function test_getP2TRScriptPubKey_Success_ScriptPath() external pure {
        // Arrenge
        // Data from https://learnmeabitcoin.com/technical/upgrades/taproot/#scriptpubkey
        bytes32 publicKey = 0xa2fc329a085d8cfc4fa28795993d7b666cee024e94c40115141b8e9be4a29fa4;
        bytes32 merkleRoot = 0xb5b72eea07b3e338962944a752a98772bbe1f1b6550e6fb6ab8c6e6adb152e7c;
        // Act
        bytes memory scriptPubKey = BtcAddressParser.getP2TRScriptPubKey(publicKey, merkleRoot);
        // Assert
        assertEq(
            scriptPubKey,
            hex"5120562529047f476b9a833a5a780a75845ec32980330d76d1ac9f351dc76bce5d72",
            "getP2TRScriptPubKey ScriptPath should give the correct Script public key"
        );
    }
}
