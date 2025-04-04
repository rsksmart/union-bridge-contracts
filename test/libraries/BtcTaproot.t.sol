// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {BtcTaproot} from "src/libraries/BtcTaproot.sol";
import {BtcScriptParser} from "src/libraries/BtcScriptParser.sol";

contract TestBtcTaproot is Test {
    function setUp() external {}

    function test_taggedHash_Success() external pure {
        // Arrange
        bytes memory data = hex"c0025187";
        // Act
        bytes32 leafHash = BtcTaproot.taggedHash("TapLeaf", data);
        // Assert
        assertEq(
            leafHash,
            0x6b13becdaf0eee497e2f304adcfa1c0c9e84561c9989b7f2b5fc39f5f90a60f6,
            "Should give the correct tagged hash"
        );
    }

    function test_getTweak_LearnMeABitcoin_Success() external pure {
        // LearnMeABitcoin example
        // Arrange
        bytes32 publicKey = 0xa2fc329a085d8cfc4fa28795993d7b666cee024e94c40115141b8e9be4a29fa4;
        bytes32 merkleRoot = 0xb5b72eea07b3e338962944a752a98772bbe1f1b6550e6fb6ab8c6e6adb152e7c;
        bytes memory data = abi.encodePacked(publicKey, merkleRoot);
        // Act
        bytes32 tweak = BtcTaproot.getTweak(data);
        // Assert
        assertEq(
            tweak, 0xbf0094eae70ba67e2f9fc3c4b81f078c90931855a8d24c959619174c92060cde, "Should give the correct tweak"
        );
    }

    function test_getTweak_Transactions_Success() external pure {
        // Pegin Transactions repository example
        // Arrange
        bytes32 publicKey = 0xd1cfc2049322ff6ba3a88c6e17c6622308f0fb1d2910ffadb309e4116358723d; // derive(0)
        bytes32 merkleRoot = 0x0abf845c1ebde2f3bd0f8bc4ed12be2a589e4b6190a70e58807d8ef05a5a299e; // timelock(1)
        bytes memory data = abi.encodePacked(publicKey, merkleRoot);
        // Act
        bytes32 tweak = BtcTaproot.getTweak(data);
        // Assert
        assertEq(
            tweak, 0x61918cd0faee4744226968d7f616d13aca9a553fd32ef862dfa511184497b2f8, "Should give the correct tweak"
        );
    }

    function test_getTweakedPublicKey_Success() external pure {
        // Pegin Transactions repository example
        // Arrange
        bytes32 publicKey = 0xd1cfc2049322ff6ba3a88c6e17c6622308f0fb1d2910ffadb309e4116358723d; // derive(0)
        bytes32 merkleRoot = 0x0abf845c1ebde2f3bd0f8bc4ed12be2a589e4b6190a70e58807d8ef05a5a299e; // timelock(1)
        bytes memory data = abi.encodePacked(publicKey, merkleRoot);
        bytes32 tweak = BtcTaproot.getTweak(data);
        // Act
        bytes32 tweakedPublicKey = BtcTaproot.getTweakedPublicKey(publicKey, tweak);
        // Assert
        assertEq(
            tweakedPublicKey,
            0x228f281f297fd01cd363b9c93f742ba2976c1ec5a6083d9f754cb61e505356c3,
            "Should give the correct tweaked public key"
        );
    }

    function test_getP2TRScriptPubKey_Success() external pure {
        // Arrange
        bytes32 tweakedPublicKey = 0x924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a3329;
        // Act
        bytes memory scriptPubKey = BtcTaproot.getP2TRScriptPubKey(tweakedPublicKey);
        // Assert
        assertEq(
            scriptPubKey,
            hex"5120924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a3329",
            "getP2TRScriptPubKey KeyPath should give the correct Script public key"
        );
    }

    function test_getLeaf_Success() external pure {
        // Arrange
        bytes memory script = hex"5187";
        // Act
        bytes32 leafHash = BtcTaproot.getLeaf(script);
        // Assert
        assertEq(
            leafHash,
            0x6b13becdaf0eee497e2f304adcfa1c0c9e84561c9989b7f2b5fc39f5f90a60f6,
            "getLeaf should give the correct tagged hash"
        );
    }

    function test_getLeaf_TimelockScript_Success() external pure {
        // Arrange
        uint32 blocks = 1;
        bytes32 pubKey = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
        bytes memory script = BtcScriptParser.getTimelockScript(blocks, pubKey);
        // Act
        bytes32 leafHash = BtcTaproot.getLeaf(script);
        // Assert
        assertEq(
            leafHash,
            0x0abf845c1ebde2f3bd0f8bc4ed12be2a589e4b6190a70e58807d8ef05a5a299e,
            "getLeaf should give the correct tagged hash"
        );
    }

    function test_getBranch_Success() external pure {
        // Arrange
        // https://learnmeabitcoin.com/technical/upgrades/taproot/#script-tree-merkle-root-branch-hash
        bytes32 leafHash1 = 0x6b13becdaf0eee497e2f304adcfa1c0c9e84561c9989b7f2b5fc39f5f90a60f6;
        bytes32 leafHash2 = 0xed5af8352e2a54cce8d3ea326beb7907efa850bdfe3711cef9060c7bb5bcf59e;
        bytes32 leafHash3 = 0x160bd30406f8d5333be044e6d2d14624470495da8a3f91242ce338599b233931;
        bytes32 leafHash4 = 0xbf2c4bf1ca72f7b8538e9df9bdfd3ba4c305ad11587f12bbfafa00d58ad6051d;
        bytes32 leafHash5 = 0x54962df196af2827a86f4bde3cf7d7c1a9dcb6e17f660badefbc892309bb145f;

        // branch 1 (leaf 1 hash + leaf 2 hash) = 1324300a84045033ec539f60c70d582c48b9acf04150da091694d83171b44ec9
        bytes32 branch1 = BtcTaproot.getBranch(leafHash1, leafHash2);
        assertEq(
            branch1,
            0x1324300a84045033ec539f60c70d582c48b9acf04150da091694d83171b44ec9,
            "getBranch branch1 should be the correct tagged hash"
        );

        // branch 2 (branch 1 + leaf 3 hash) = beec0122bddd26f642140bcd922e0264ce1e2be5808a41ae58d82e829bc913d7
        bytes32 branch2 = BtcTaproot.getBranch(branch1, leafHash3);
        assertEq(
            branch2,
            0xbeec0122bddd26f642140bcd922e0264ce1e2be5808a41ae58d82e829bc913d7,
            "getBranch branch2 should be the correct tagged hash"
        );

        // branch 3 (branch 2 + leaf 4 hash)    = a4e0d9cc12ce2f32069e98247581d5eb9ca0a4cf175771a8df2c53a93dcb0ebd
        bytes32 branch3 = BtcTaproot.getBranch(branch2, leafHash4);
        assertEq(
            branch3,
            0xa4e0d9cc12ce2f32069e98247581d5eb9ca0a4cf175771a8df2c53a93dcb0ebd,
            "getBranch branch3 should be the correct tagged hash"
        );

        // branch 4 (leaf 5 hash + branch 3)    = b5b72eea07b3e338962944a752a98772bbe1f1b6550e6fb6ab8c6e6adb152e7c
        bytes32 branch4 = BtcTaproot.getBranch(branch3, leafHash5);
        assertEq(
            branch4,
            0xb5b72eea07b3e338962944a752a98772bbe1f1b6550e6fb6ab8c6e6adb152e7c,
            "getBranch branch4 should be the correct tagged hash"
        );
    }
}
