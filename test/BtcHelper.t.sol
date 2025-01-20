// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";

contract TestBtcHelper is Test {
    function setUp() external {}

    function test_hash256_Success() external view {
        // Arrenge
        // Obtained from Bitcoin block 879_500 using RSK precompiled bridge getBtcBlockchainBlockHeaderByHeight
        bytes memory blockBytes =
            hex"00600022bd414202c86f2e80aca72283aa584d6ee2b7597b1d6d02000000000000000000f6f5a9ccc718288b2af0c6695fec614550b3a5f4ef4c04d4116faaaa64ece1e0ac0f8967618c02173e6999e2";
        // Act
        bytes32 blockHash = BtcHelper.hash256(blockBytes);
        // Assert
        assertEq(
            blockHash,
            0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9,
            "Hashing the block with Hash256 should give the correct block hash"
        );
    }
}
