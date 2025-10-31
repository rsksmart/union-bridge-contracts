// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";

contract PauseManagerTest is HelperContract {
    function setUp() external {
        runTestDeployScript();
    }

    // ============ Pause Tests ============

    function test_pause_Success_CallFromOwner() external {
        // Arrange
        address owner = pauseManager.owner();

        // Assert - expect events from all 4 contracts
        vm.expectEmit(address(peginManager));
        emit PausableUpgradeable.Paused(address(pauseManager));
        vm.expectEmit(address(pegoutManager));
        emit PausableUpgradeable.Paused(address(pauseManager));
        vm.expectEmit(address(registry));
        emit PausableUpgradeable.Paused(address(pauseManager));
        vm.expectEmit(address(memberRegistry));
        emit PausableUpgradeable.Paused(address(pauseManager));

        // Act
        vm.prank(owner);
        pauseManager.pause();

        // Assert - all contracts are paused
        assertTrue(peginManager.isPaused());
        assertTrue(pegoutManager.isPaused());
        assertTrue(registry.isPaused());
        assertTrue(memberRegistry.isPaused());
        assertTrue(pauseManager.isPaused());
    }

    function test_pause_Revert_UnauthorizedAccount_CallFromNotOwner() external {
        // Arrange
        address notOwner = address(0x123);

        // Assert
        vm.expectRevert();

        // Act
        vm.prank(notOwner);
        pauseManager.pause();
    }

    function test_pause_Revert_EnforcedPause_AlreadyPaused() external {
        // Arrange
        address owner = pauseManager.owner();
        vm.prank(owner);
        pauseManager.pause();

        // Assert
        vm.expectRevert();

        // Act
        vm.prank(owner);
        pauseManager.pause();
    }

    // ============ Unpause Tests ============

    function test_unpause_Success_CallFromOwner() external {
        // Arrange
        address owner = pauseManager.owner();
        vm.prank(owner);
        pauseManager.pause();

        // Assert - expect events from all 4 contracts
        vm.expectEmit(address(peginManager));
        emit PausableUpgradeable.Unpaused(address(pauseManager));
        vm.expectEmit(address(pegoutManager));
        emit PausableUpgradeable.Unpaused(address(pauseManager));
        vm.expectEmit(address(registry));
        emit PausableUpgradeable.Unpaused(address(pauseManager));
        vm.expectEmit(address(memberRegistry));
        emit PausableUpgradeable.Unpaused(address(pauseManager));

        // Act
        vm.prank(owner);
        pauseManager.unpause();

        // Assert - all contracts are unpaused
        assertFalse(peginManager.isPaused());
        assertFalse(pegoutManager.isPaused());
        assertFalse(registry.isPaused());
        assertFalse(memberRegistry.isPaused());
        assertFalse(pauseManager.isPaused());
    }

    function test_unpause_Revert_UnauthorizedAccount_CallFromNotOwner() external {
        // Arrange
        address owner = pauseManager.owner();
        vm.prank(owner);
        pauseManager.pause();
        address notOwner = address(0x123);

        // Assert
        vm.expectRevert();

        // Act
        vm.prank(notOwner);
        pauseManager.unpause();
    }

    function test_unpause_Revert_ExpectedPause_NotPaused() external {
        // Arrange
        address owner = pauseManager.owner();

        // Assert
        vm.expectRevert();

        // Act
        vm.prank(owner);
        pauseManager.unpause();
    }

    // ============ isPaused Tests ============

    function test_isPaused_ReturnsFalse_WhenNonePaused() external view {
        // Assert
        assertFalse(pauseManager.isPaused());
    }

    function test_isPaused_ReturnsTrue_WhenPeginManagerPaused() external {
        // Arrange
        vm.prank(pauseManager.owner());
        pauseManager.pause();

        // Assert
        assertTrue(pauseManager.isPaused());
    }

    function test_isPaused_ReturnsTrue_WhenAllPaused() external {
        // Arrange
        vm.prank(pauseManager.owner());
        pauseManager.pause();

        // Assert
        assertTrue(pauseManager.isPaused());
        assertTrue(peginManager.isPaused());
        assertTrue(pegoutManager.isPaused());
        assertTrue(registry.isPaused());
        assertTrue(memberRegistry.isPaused());
    }

    // ============ Pauser Assignment Tests ============

    function test_Success_PauserIsPauseManager_PeginManager() external view {
        assertEq(peginManager.pauser(), address(pauseManager));
    }

    function test_Success_PauserIsPauseManager_PegoutManager() external view {
        assertEq(pegoutManager.pauser(), address(pauseManager));
    }

    function test_Success_PauserIsPauseManager_CommitteeRegistry() external view {
        assertEq(registry.pauser(), address(pauseManager));
    }

    function test_Success_PauserIsPauseManager_MemberRegistry() external view {
        assertEq(memberRegistry.pauser(), address(pauseManager));
    }
}
