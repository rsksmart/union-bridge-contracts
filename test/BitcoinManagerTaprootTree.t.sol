// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BitcoinManagerHarness} from "test/helpers/BitcoinManagerHarness.sol";
import {BtcTaproot} from "src/libraries/BtcTaproot.sol";
import {OpCodes} from "src/libraries/OpCodes.sol";

/// @title BitcoinManagerTaprootTreeTest
/// @notice Tests for the balanced Taproot merkle tree implementation
/// @dev Ports tests from Rust to verify taproot tree balancing matches Bitcoin Core's TaprootBuilder
///
/// VERIFICATION RESULTS:
/// These tests use the same aggregated public key as the BitVMX Rust implementation
/// and produce identical merkle roots, confirming correct porting and tree balancing.
///
/// Verified Merkle Roots (matching BitVMX):
/// - 1 leaf:    0xba333a029c37be04e148f5d9f1a1032e4b9a1c614f9ad9cc5462b42ec49e8041
/// - 2 leaves:  0xdc1ac07396af90fdc63dae2f6fb6a0b4b1cde7adb63da28df495d62ef1ba06d1
/// - 3 leaves:  0x4d742ed6a6eb24544660936e2a6ab3585d2b234d50ed228a133cf00a74f76895
/// - 4 leaves:  0x696879cac4f462d7882c08de9e81b374f8b1857ae333db12049214d21b48d056
/// - 5 leaves:  0x9002865e9dde99417b3ac4cf56f3c5abc688956b0ae9600444459c798820e4ed
/// - 6 leaves:  0x423002cf811c1581b8b7ae4baeff6749e87aa59e5a0053a0f8a368ca594aa242
/// - 7 leaves:  0x1b33df01dc8d27745ab6ffdb43643febdaa9fb304d7805bdac20622cc773c710
/// - 10 leaves: 0xc2fd9cc1adfe6f3ce291403af4dd0789a9cbe993489c4e548f1a5dc4bfe321d0
/// - Empty:     0x0000000000000000000000000000000000000000000000000000000000000000
///
/// This verification confirms that the balanced binary tree construction in Solidity
/// produces the same results as Bitcoin Core's TaprootBuilder algorithm.
contract BitcoinManagerTaprootTreeTest is Test {
    BitcoinManagerHarness public bitcoinManager;

    // Test public key (same as Rust tests)
    bytes constant PUBKEY = hex"02c6047f9441ed7d6d3045406e95c07cd85a6a6d4c90d35b8c6a568f07cfd511fd";
    bytes32 constant PUBKEY_X = 0xc6047f9441ed7d6d3045406e95c07cd85a6a6d4c90d35b8c6a568f07cfd511fd;

    function setUp() public {
        bitcoinManager = new BitcoinManagerHarness();
    }

    /// @notice Builds a merkle tree and returns the root using the harness
    function buildMerkleTree(bytes32[] memory leaves) internal view returns (bytes32) {
        return bitcoinManager.buildMerkleTreeFromLeaves(leaves);
    }

    /// @notice Creates a timelock script (similar to Rust's timelock function)
    /// @param timelock The timelock value
    /// @param pubkey The public key (x-only, 32 bytes)
    /// @return The script bytes
    function createTimelockScript(uint32 timelock, bytes32 pubkey) internal pure returns (bytes memory) {
        bytes memory timelockBytes;

        // Encode timelock as minimal bytes (similar to Bitcoin's script number encoding)
        if (timelock == 0) {
            timelockBytes = hex"00"; // OP_0
        } else if (timelock <= 16) {
            timelockBytes = abi.encodePacked(uint8(uint8(OpCodes.OP_1) + timelock - 1));
        } else if (timelock < 0x100) {
            timelockBytes = abi.encodePacked(OpCodes.OP_PUSHBYTES_1, uint8(timelock));
        } else if (timelock < 0x10000) {
            timelockBytes = abi.encodePacked(OpCodes.OP_PUSHBYTES_2, uint16(timelock));
        } else if (timelock < 0x1000000) {
            timelockBytes = abi.encodePacked(OpCodes.OP_PUSHBYTES_3, uint24(timelock));
        } else {
            timelockBytes = abi.encodePacked(OpCodes.OP_PUSHBYTES_4, timelock);
        }

        // Build script: <timelock> OP_CHECKSEQUENCEVERIFY OP_DROP <pubkey> OP_CHECKSIG
        return abi.encodePacked(
            timelockBytes,
            OpCodes.OP_CHECKSEQUENCEVERIFY,
            OpCodes.OP_DROP,
            OpCodes.OP_PUSHBYTES_32,
            pubkey,
            OpCodes.OP_CHECKSIG
        );
    }

    // ============= Tests =============

    function test_buildTaprootTree_OneLeaf() public view {
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = BtcTaproot.getLeaf(createTimelockScript(1, PUBKEY_X));

        // For a single leaf, the merkle root is the leaf itself
        bytes32 expectedRoot = leaves[0];
        bytes32 actualRoot = bitcoinManager.buildMerkleTreeFromLeaves(leaves);

        assertEq(actualRoot, expectedRoot, "Single leaf merkle root should equal the leaf");
        assertTrue(actualRoot != bytes32(0), "Merkle root should not be zero");
    }

    function test_buildTaprootTree_TwoLeaves() public view {
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = BtcTaproot.getLeaf(createTimelockScript(1, PUBKEY_X));
        leaves[1] = BtcTaproot.getLeaf(createTimelockScript(2, PUBKEY_X));

        // For two leaves at depth 0, they should be combined at the root
        bytes32 expectedRoot = BtcTaproot.getBranch(leaves[0], leaves[1]);
        bytes32 actualRoot = bitcoinManager.buildMerkleTreeFromLeaves(leaves);

        assertEq(actualRoot, expectedRoot, "Two leaves merkle root should be branch of both leaves");
        assertTrue(actualRoot != bytes32(0), "Merkle root should not be zero");
    }

    function test_buildTaprootTree_ThreeLeaves() public view {
        bytes32[] memory leaves = new bytes32[](3);
        for (uint32 i = 0; i < 3; i++) {
            leaves[i] = BtcTaproot.getLeaf(createTimelockScript(i + 1, PUBKEY_X));
        }

        bytes32 expectedRoot = 0x4d742ed6a6eb24544660936e2a6ab3585d2b234d50ed228a133cf00a74f76895;
        bytes32 merkleRoot = bitcoinManager.buildMerkleTreeFromLeaves(leaves);

        assertEq(merkleRoot, expectedRoot, "Three leaves merkle root should match BitVMX");
    }

    function test_buildTaprootTree_FourLeaves() public view {
        bytes32[] memory leaves = new bytes32[](4);
        for (uint32 i = 0; i < 4; i++) {
            leaves[i] = BtcTaproot.getLeaf(createTimelockScript(i + 1, PUBKEY_X));
        }

        bytes32 expectedRoot = 0x696879cac4f462d7882c08de9e81b374f8b1857ae333db12049214d21b48d056;
        bytes32 merkleRoot = bitcoinManager.buildMerkleTreeFromLeaves(leaves);

        assertEq(merkleRoot, expectedRoot, "Four leaves merkle root should match BitVMX");
    }

    function test_buildTaprootTree_FiveLeaves() public view {
        bytes32[] memory leaves = new bytes32[](5);
        for (uint32 i = 0; i < 5; i++) {
            leaves[i] = BtcTaproot.getLeaf(createTimelockScript(i + 1, PUBKEY_X));
        }

        bytes32 expectedRoot = 0x9002865e9dde99417b3ac4cf56f3c5abc688956b0ae9600444459c798820e4ed;
        bytes32 merkleRoot = bitcoinManager.buildMerkleTreeFromLeaves(leaves);

        assertEq(merkleRoot, expectedRoot, "Five leaves merkle root should match BitVMX");
    }

    function test_buildTaprootTree_SixLeaves() public view {
        bytes32[] memory leaves = new bytes32[](6);
        for (uint32 i = 0; i < 6; i++) {
            leaves[i] = BtcTaproot.getLeaf(createTimelockScript(i + 1, PUBKEY_X));
        }

        bytes32 expectedRoot = 0x423002cf811c1581b8b7ae4baeff6749e87aa59e5a0053a0f8a368ca594aa242;
        bytes32 merkleRoot = bitcoinManager.buildMerkleTreeFromLeaves(leaves);

        assertEq(merkleRoot, expectedRoot, "Six leaves merkle root should match BitVMX");
    }

    function test_buildTaprootTree_SevenLeaves() public view {
        bytes32[] memory leaves = new bytes32[](7);
        for (uint32 i = 0; i < 7; i++) {
            leaves[i] = BtcTaproot.getLeaf(createTimelockScript(i + 1, PUBKEY_X));
        }

        bytes32 expectedRoot = 0x1b33df01dc8d27745ab6ffdb43643febdaa9fb304d7805bdac20622cc773c710;
        bytes32 merkleRoot = bitcoinManager.buildMerkleTreeFromLeaves(leaves);

        assertEq(merkleRoot, expectedRoot, "Seven leaves merkle root should match BitVMX");
    }

    function test_buildTaprootTree_TenLeaves() public view {
        bytes32[] memory leaves = new bytes32[](10);
        for (uint32 i = 0; i < 10; i++) {
            leaves[i] = BtcTaproot.getLeaf(createTimelockScript(i + 1, PUBKEY_X));
        }

        bytes32 expectedRoot = 0xc2fd9cc1adfe6f3ce291403af4dd0789a9cbe993489c4e548f1a5dc4bfe321d0;
        bytes32 merkleRoot = bitcoinManager.buildMerkleTreeFromLeaves(leaves);

        assertEq(merkleRoot, expectedRoot, "Ten leaves merkle root should match BitVMX");
    }

    /// @notice Test edge cases
    function test_buildTaprootTree_EdgeCases() public view {
        // Test empty array
        bytes32[] memory emptyLeaves = new bytes32[](0);
        bytes32 emptyRoot = bitcoinManager.buildMerkleTreeFromLeaves(emptyLeaves);
        assertEq(emptyRoot, bytes32(0), "Empty leaves should return zero");
    }
}
