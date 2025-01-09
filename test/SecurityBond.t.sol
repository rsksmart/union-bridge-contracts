// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "src/SecurityBond.sol";
import "src/PegManager.sol";
import "src/CommitteeRegistry.sol";
import "src/BitcoinManager.sol";

contract TestSecurityBond is Test {
    SecurityBond sb;

    function setUp() external {
        BitcoinManager bitcoinManager = new BitcoinManager();
        CommitteeRegistry registry = new CommitteeRegistry();
        PegManager pm = new PegManager(registry, bitcoinManager);
        sb = new SecurityBond(pm);
    }

    function test_getMinimumDeposit() external {
        // Arrenge
        uint64 denomination = 100_000; // 0.001 BTC
        // Act
        uint64 minDeposit = sb.getMinimumDeposit(denomination);
        // Assert
        assertEq(minDeposit, denomination * 2, "Error SecurityBond min deposit should be twice the denomination");
    }

    function test_securityBondDeposit_success() public {
        // Arrenge
        uint64 denomination = 100_000; // 0.001 BTC
        uint256 balanceBefore = address(sb).balance;
        address sender = address(this);
        uint256 depositBalanceBefore = sb.depositedSecurityBond(sender);
        uint256 value = 1 ether;
        // Act
        sb.securityBondDeposit{value: value}(denomination);
        // Assert
        uint256 balanceAfter = address(sb).balance;
        uint256 depositBalanceAfter = sb.depositedSecurityBond(sender);

        assertEq(balanceAfter - balanceBefore, value, "expect security bond value increase of 1 ether");
        assertEq(depositBalanceAfter - depositBalanceBefore, value, "expect security bond mapping increase of 1 ether");
    }

    function test_securityBondDeposit_revert() public {
        // Arrenge
        uint64 denomination = 100_000; // 0.001 BTC
        // Assert
        vm.expectRevert(abi.encodeWithSelector(SecurityBond.despositBondTooLow.selector, 0, denomination * 2));
        // Act
        sb.securityBondDeposit{value: 0}(denomination);
    }
}
