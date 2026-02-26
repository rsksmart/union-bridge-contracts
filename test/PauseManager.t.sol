// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IPauseManager} from "src/interfaces/IPauseManager.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";

contract accessManagerTest is HelperContract {
    function setUp() external {
        runTestDeployScript();
    }

    // ============ Pause Tests ============

    function test_pause_Success_CallFromOwner() external {
        // Arrange
        address owner = accessManager.owner();

        // Assert - expect events from all pausable contracts
        vm.expectEmit(address(peginManager));
        emit PausableUpgradeable.Paused(address(accessManager));
        vm.expectEmit(address(pegoutManager));
        emit PausableUpgradeable.Paused(address(accessManager));
        vm.expectEmit(address(registry));
        emit PausableUpgradeable.Paused(address(accessManager));
        vm.expectEmit(address(memberRegistry));
        emit PausableUpgradeable.Paused(address(accessManager));
        vm.expectEmit(address(rbtcBridge));
        emit PausableUpgradeable.Paused(address(accessManager));
        vm.expectEmit(address(challengeManager));
        emit PausableUpgradeable.Paused(address(accessManager));
        vm.expectEmit(address(operatorTakeManager));
        emit PausableUpgradeable.Paused(address(accessManager));

        // Act
        vm.prank(owner);
        accessManager.pause();

        // Assert - all contracts are paused
        assertTrue(peginManager.isPaused());
        assertTrue(pegoutManager.isPaused());
        assertTrue(registry.isPaused());
        assertTrue(memberRegistry.isPaused());
        assertTrue(rbtcBridge.isPaused());
        assertTrue(challengeManager.isPaused());
        assertTrue(operatorTakeManager.isPaused());
        assertTrue(accessManager.areContractsPaused());
    }

    function test_pause_Revert_UnauthorizedAccount_CallFromNotOwner() external {
        // Arrange
        address notOwner = address(0x123);

        // Assert
        vm.expectRevert();

        // Act
        vm.prank(notOwner);
        accessManager.pause();
    }

    function test_pause_Revert_EnforcedPause_AlreadyPaused() external {
        // Arrange
        address owner = accessManager.owner();
        vm.prank(owner);
        accessManager.pause();

        // Assert
        vm.expectRevert();

        // Act
        vm.prank(owner);
        accessManager.pause();
    }

    // ============ Unpause Tests ============

    function test_unpause_Success_CallFromOwner() external {
        // Arrange
        address owner = accessManager.owner();
        vm.prank(owner);
        accessManager.pause();

        // Assert - expect events from all pausable contracts
        vm.expectEmit(address(peginManager));
        emit PausableUpgradeable.Unpaused(address(accessManager));
        vm.expectEmit(address(pegoutManager));
        emit PausableUpgradeable.Unpaused(address(accessManager));
        vm.expectEmit(address(registry));
        emit PausableUpgradeable.Unpaused(address(accessManager));
        vm.expectEmit(address(memberRegistry));
        emit PausableUpgradeable.Unpaused(address(accessManager));
        vm.expectEmit(address(rbtcBridge));
        emit PausableUpgradeable.Unpaused(address(accessManager));
        vm.expectEmit(address(challengeManager));
        emit PausableUpgradeable.Unpaused(address(accessManager));
        vm.expectEmit(address(operatorTakeManager));
        emit PausableUpgradeable.Unpaused(address(accessManager));

        // Act
        vm.prank(owner);
        accessManager.unpause();

        // Assert - all contracts are unpaused
        assertFalse(peginManager.isPaused());
        assertFalse(pegoutManager.isPaused());
        assertFalse(registry.isPaused());
        assertFalse(memberRegistry.isPaused());
        assertFalse(rbtcBridge.isPaused());
        assertFalse(challengeManager.isPaused());
        assertFalse(operatorTakeManager.isPaused());
        assertFalse(accessManager.areContractsPaused());
    }

    function test_unpause_Revert_UnauthorizedAccount_CallFromNotOwner() external {
        // Arrange
        address owner = accessManager.owner();
        vm.prank(owner);
        accessManager.pause();
        address notOwner = address(0x123);

        // Assert
        vm.expectRevert();

        // Act
        vm.prank(notOwner);
        accessManager.unpause();
    }

    function test_unpause_Revert_ExpectedPause_NotPaused() external {
        // Arrange
        address owner = accessManager.owner();

        // Assert
        vm.expectRevert();

        // Act
        vm.prank(owner);
        accessManager.unpause();
    }

    // ============ areContractsPaused Tests ============

    function test_areContractsPaused_ReturnsFalse_WhenNonePaused() external view {
        // Assert
        assertFalse(accessManager.areContractsPaused());
    }

    function test_areContractsPaused_ReturnsTrue_WhenAllPaused() external {
        // Arrange
        vm.prank(accessManager.owner());
        accessManager.pause();

        // Assert
        assertTrue(accessManager.areContractsPaused());
        assertTrue(peginManager.isPaused());
        assertTrue(pegoutManager.isPaused());
        assertTrue(registry.isPaused());
        assertTrue(memberRegistry.isPaused());
        assertTrue(rbtcBridge.isPaused());
        assertTrue(challengeManager.isPaused());
        assertTrue(operatorTakeManager.isPaused());
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
        assertFalse(challengeManager.isPaused());

        // Assert - should revert when states are inconsistent
        vm.expectRevert(IPauseManager._InconsistentPauseState.selector);

        // Act
        accessManager.areContractsPaused();
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
        accessManager.areContractsPaused();
    }

    function test_areContractsPaused_Revert_InconsistentPauseState_AllPausedThenOneUnpaused() external {
        // Arrange - pause all contracts, then manually unpause one
        vm.prank(accessManager.owner());
        accessManager.pause();

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
        accessManager.areContractsPaused();
    }

    // ============ Pauser Assignment Tests ============

    function test_Success_PauserIsaccessManager_PeginManager() external view {
        assertEq(peginManager.pauser(), address(accessManager));
    }

    function test_Success_PauserIsaccessManager_PegoutManager() external view {
        assertEq(pegoutManager.pauser(), address(accessManager));
    }

    function test_Success_PauserIsaccessManager_CommitteeRegistry() external view {
        assertEq(registry.pauser(), address(accessManager));
    }

    function test_Success_PauserIsaccessManager_MemberRegistry() external view {
        assertEq(memberRegistry.pauser(), address(accessManager));
    }

    function test_Success_PauserIsPauseManager_RbtcBridge() external view {
        assertEq(rbtcBridge.pauser(), address(accessManager));
    }

    function test_Success_OperatorTakeManagerIsSet() external view {
        assertEq(address(accessManager.operatorTakeManager()), address(operatorTakeManager));
    }
}
