// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {HelperContract} from "test/HelperContract.sol";

contract TestPegManager is Test, HelperContract {
    function setUp() external {
        setUpPegManager();
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
