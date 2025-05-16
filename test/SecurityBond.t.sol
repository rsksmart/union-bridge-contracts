// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IStreamManager} from "src/interfaces/IStreamManager.sol";
import {SecurityBond, MemberBalance} from "src/SecurityBond.sol";
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

    function test_securityBondDeposit_Success() public {
        // Arrange
        uint64 denomination = 100_000; // 0.001 BTC
        uint256 balanceBefore = address(registry).balance;
        address sender = address(this);
        uint256 depositBalanceBefore = registry.getMemberBalance(sender).total;
        uint256 value = 1 ether;
        // Act
        registry.securityBondDeposit{value: value}(denomination);
        // Assert
        uint256 balanceAfter = address(registry).balance;
        uint256 depositBalanceAfter = registry.getMemberBalance(sender).total;

        assertEq(balanceAfter - balanceBefore, value, "expect security bond value increase of 1 ether");
        assertEq(depositBalanceAfter - depositBalanceBefore, value, "expect security bond mapping increase of 1 ether");
    }

    function test_securityBondDeposit_Revert_DespositBondTooLow() public {
        // Arrange
        uint64 denomination = 100_000; // 0.001 BTC
        uint256 securityBond = registry.getMinimumDeposit(denomination) - 1;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                SecurityBond.despositBondTooLow.selector, securityBond, BtcHelper.satoshiToWei(denomination) / 10
            )
        );
        // Act
        registry.securityBondDeposit{value: securityBond}(denomination);
    }
}
