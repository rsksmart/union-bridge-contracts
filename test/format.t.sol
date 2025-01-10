// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract FormatTest is Test {
    function testFormat() public {
        string[] memory inputs = new string[](3);
        inputs[0] = "forge";
        inputs[1] = "fmt";
        inputs[2] = "--check";

        // Execute forge fmt --check as a command
        bytes memory res = vm.ffi(inputs);

        // If format check fails, this will revert
        require(res.length == 0, "Format check failed");
    }
}
