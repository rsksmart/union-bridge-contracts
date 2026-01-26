// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IPauseManager} from "src/interfaces/IPauseManager.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";

contract PauseManagerTest is HelperContract {
    function setUp() external {
        runTestDeployScript();
    }

    // ============ Pause Tests ============

    function test_pause_Success_CallFromOwner() external {
        // Arrange
        address owner = pauseManager.owner();

        // Assert - expect events from all 5 contracts
        vm.expectEmit(address(peginManager));
        emit PausableUpgradeable.Paused(address(pauseManager));
        vm.expectEmit(address(pegoutManager));
        emit PausableUpgradeable.Paused(address(pauseManager));
        vm.expectEmit(address(registry));
        emit PausableUpgradeable.Paused(address(pauseManager));
        vm.expectEmit(address(memberRegistry));
        emit PausableUpgradeable.Paused(address(pauseManager));
        vm.expectEmit(address(rbtcBridge));
        emit PausableUpgradeable.Paused(address(pauseManager));

        // Act
        vm.prank(owner);
        pauseManager.pause();

        // Assert - all contracts are paused
        assertTrue(peginManager.isPaused());
        assertTrue(pegoutManager.isPaused());
        assertTrue(registry.isPaused());
        assertTrue(memberRegistry.isPaused());
        assertTrue(rbtcBridge.isPaused());
        assertTrue(pauseManager.areContractsPaused());
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

        // Assert - expect events from all 5 contracts
        vm.expectEmit(address(peginManager));
        emit PausableUpgradeable.Unpaused(address(pauseManager));
        vm.expectEmit(address(pegoutManager));
        emit PausableUpgradeable.Unpaused(address(pauseManager));
        vm.expectEmit(address(registry));
        emit PausableUpgradeable.Unpaused(address(pauseManager));
        vm.expectEmit(address(memberRegistry));
        emit PausableUpgradeable.Unpaused(address(pauseManager));
        vm.expectEmit(address(rbtcBridge));
        emit PausableUpgradeable.Unpaused(address(pauseManager));

        // Act
        vm.prank(owner);
        pauseManager.unpause();

        // Assert - all contracts are unpaused
        assertFalse(peginManager.isPaused());
        assertFalse(pegoutManager.isPaused());
        assertFalse(registry.isPaused());
        assertFalse(memberRegistry.isPaused());
        assertFalse(rbtcBridge.isPaused());
        assertFalse(pauseManager.areContractsPaused());
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

    // ============ areContractsPaused Tests ============

    function test_areContractsPaused_ReturnsFalse_WhenNonePaused() external view {
        // Assert
        assertFalse(pauseManager.areContractsPaused());
    }

    function test_areContractsPaused_ReturnsTrue_WhenAllPaused() external {
        // Arrange
        vm.prank(pauseManager.owner());
        pauseManager.pause();

        // Assert
        assertTrue(pauseManager.areContractsPaused());
        assertTrue(peginManager.isPaused());
        assertTrue(pegoutManager.isPaused());
        assertTrue(registry.isPaused());
        assertTrue(memberRegistry.isPaused());
        assertTrue(rbtcBridge.isPaused());
    }

    function test_areContractsPaused_Revert_InconsistentPauseState_SingleContractPaused() external {
        // Arrange - manually pause PeginManager contract to create an inconsistent state
        address pauser = peginManager.pauser();
        vm.prank(pauser);
        peginManager.pause();

        // Assert - verify that only PeginManager contract is paused
        assertTrue(peginManager.isPaused());
        assertFalse(pegoutManager.isPaused());
        assertFalse(registry.isPaused());
        assertFalse(memberRegistry.isPaused());
        assertFalse(rbtcBridge.isPaused());

        // Assert - should revert when states are inconsistent
        vm.expectRevert(IPauseManager._InconsistentPauseState.selector);

        // Act
        pauseManager.areContractsPaused();
    }

    function test_areContractsPaused_Revert_InconsistentPauseState_MultiplePaused() external {
        // Arrange - manually pause some contracts but not all to create inconsistent state
        address pauser = peginManager.pauser();
        vm.startPrank(pauser);
        peginManager.pause();
        pegoutManager.pause();
        vm.stopPrank();

        // Assert - should revert when states are inconsistent
        vm.expectRevert(IPauseManager._InconsistentPauseState.selector);

        // Act
        pauseManager.areContractsPaused();
    }

    function test_areContractsPaused_Revert_InconsistentPauseState_AllPausedThenOneUnpaused() external {
        // Arrange - pause all contracts, then manually unpause one
        vm.prank(pauseManager.owner());
        pauseManager.pause();

        // Manually unpause one contract to create inconsistent state
        address pauser = peginManager.pauser();
        vm.prank(pauser);
        peginManager.unpause();

        // Assert - verify inconsistent state
        assertFalse(peginManager.isPaused());
        assertTrue(pegoutManager.isPaused());
        assertTrue(registry.isPaused());
        assertTrue(memberRegistry.isPaused());
        assertTrue(rbtcBridge.isPaused());

        // Assert - should revert when states are inconsistent
        vm.expectRevert(IPauseManager._InconsistentPauseState.selector);

        // Act
        pauseManager.areContractsPaused();
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

    function test_Success_PauserIsPauseManager_RbtcBridge() external view {
        assertEq(rbtcBridge.pauser(), address(pauseManager));
    }
}
