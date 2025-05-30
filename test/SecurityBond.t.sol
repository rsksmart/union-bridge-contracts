// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IStreamManager} from "src/interfaces/IStreamManager.sol";
import {SecurityBond} from "src/SecurityBond.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";

contract TestSecurityBond is Test, HelperContract {
    function setUp() external {
        runTestDeployScript();
    }

    function test_getMinimumDeposit_Success() external view {
        // Arrange
        uint64 denomination = 100_000; // 0.001 BTC
        // Act
        uint256 minDeposit = registry.getMinimumDeposit(denomination);
        // Assert
        assertEq(
            minDeposit,
            BtcHelper.satoshiToWei(denomination) / 10,
            "Error SecurityBond min deposit should be equal to the denomination"
        );
    }

    function test_getMinimumDeposit_Revert_StreamNotFound() external {
        // Arrange
        uint64 denomination = 111_000; // 0.001 BTC
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.StreamNotFoundByDenomination.selector, denomination));
        // Act
        registry.getMinimumDeposit(denomination);
    }
}
