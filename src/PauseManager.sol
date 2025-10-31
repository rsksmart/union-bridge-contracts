// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BaseProxy} from "./BaseProxy.sol";
import {IPauseManager} from "./interfaces/IPauseManager.sol";
import {IPausable} from "./interfaces/IPausable.sol";

/// @title PauseManager
/// @notice Centralized pause manager for all pausable contracts in the union bridge system
/// @dev This contract is responsible for pausing/unpausing all pausable contracts
contract PauseManager is IPauseManager, BaseProxy {
    /// @notice The PeginManager contract
    IPausable public peginManager;

    /// @notice The PegoutManager contract
    IPausable public pegoutManager;

    /// @notice The CommitteeRegistry contract
    IPausable public committeeRegistry;

    /// @notice The MemberRegistry contract
    IPausable public memberRegistry;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the PauseManager contract
    /// @param _initialOwner The initial owner of the contract who can pause/unpause
    /// @param _peginManager The address of the PeginManager contract
    /// @param _pegoutManager The address of the PegoutManager contract
    /// @param _committeeRegistry The address of the CommitteeRegistry contract
    /// @param _memberRegistry The address of the MemberRegistry contract
    function initialize(
        address _initialOwner,
        address _peginManager,
        address _pegoutManager,
        address _committeeRegistry,
        address _memberRegistry
    ) external initializer {
        if (_peginManager == address(0)) {
            revert ZeroAddress();
        }
        if (_pegoutManager == address(0)) {
            revert ZeroAddress();
        }
        if (_committeeRegistry == address(0)) {
            revert ZeroAddress();
        }
        if (_memberRegistry == address(0)) {
            revert ZeroAddress();
        }

        peginManager = IPausable(_peginManager);
        pegoutManager = IPausable(_pegoutManager);
        committeeRegistry = IPausable(_committeeRegistry);
        memberRegistry = IPausable(_memberRegistry);

        __BaseProxy_init(_initialOwner);
    }

    /// @notice Pauses all pausable contracts
    /// @dev Only callable by the contract owner
    function pause() external onlyOwner {
        peginManager.pause();
        pegoutManager.pause();
        committeeRegistry.pause();
        memberRegistry.pause();
    }

    /// @notice Unpauses all pausable contracts
    /// @dev Only callable by the contract owner
    function unpause() external onlyOwner {
        peginManager.unpause();
        pegoutManager.unpause();
        committeeRegistry.unpause();
        memberRegistry.unpause();
    }

    /// @notice Returns true if any of the contracts is paused
    /// @dev Returns true if at least one contract is paused
    function isPaused() external view returns (bool) {
        return peginManager.isPaused() || pegoutManager.isPaused() || committeeRegistry.isPaused()
            || memberRegistry.isPaused();
    }
}
