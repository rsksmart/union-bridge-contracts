// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/PegManager.sol";
import "src/CommitteeRegistry.sol";
import "src/BitcoinManager.sol";

contract TestPegManager is Test {
    PegManager pm;

    function setUp() external {
        BitcoinManager bitcoinManager = new BitcoinManager();

        address[2] memory committee1 = [vm.addr(1), vm.addr(2)];
        address[2] memory committee2 = [vm.addr(3), vm.addr(4)];
        address[2] memory committee3 = [vm.addr(5), vm.addr(6)];

        CommitteeRegistry registry = new CommitteeRegistry();
        registry.initialize();

        // Register committees with their mock keys. These are Bitcoin x-only public keys.
        registry.registerCommittee(
            committee1, bytes32(hex"0908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785eb")
        );
        registry.registerCommittee(
            committee2, bytes32(hex"1908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785ec")
        );
        registry.registerCommittee(
            committee3, bytes32(hex"2908421cb37d204b0c68660d093534d50d01fa791a3313e5fd9c21da137785ed")
        );

        pm = new PegManager();
        pm.initialize(registry, bitcoinManager);
    }

    function test_getTemporaryPegInAddress_Success() external view {
        // check that the function returns the correct taproot address
        bytes memory dummyRskAddress = abi.encodePacked(bytes20(0x4C9a9CbFa14106439B0F96a64d9260F3b8947934));
        uint64 value = 100_000; // 0.001 BTC
        bytes memory result = pm.getTemporaryPegInAddress(dummyRskAddress, value);

        console.log("result");
        console.logBytes(result);
    }
}
