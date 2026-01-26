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

    /// @notice The RbtcBridge contract
    IPausable public rbtcBridge;

    /// @notice The ChallengeManager contract
    IPausable public challengeManager;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the PauseManager contract
    /// @param _initialOwner The initial owner of the contract who can pause/unpause
    /// @param _peginManager The address of the PeginManager contract
    /// @param _pegoutManager The address of the PegoutManager contract
    /// @param _challengeManager The address of the ChallengeManager contract
    /// @param _committeeRegistry The address of the CommitteeRegistry contract
    /// @param _memberRegistry The address of the MemberRegistry contract
    /// @param _rbtcBridge The address of the RbtcBridge contract
    function initialize(
        address _initialOwner,
        address _peginManager,
        address _pegoutManager,
        address _challengeManager,
        address _committeeRegistry,
        address _memberRegistry,
        address _rbtcBridge
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
        if (_rbtcBridge == address(0)) {
            revert ZeroAddress();
        }
        if (_challengeManager == address(0)) {
            revert ZeroAddress();
        }

        peginManager = IPausable(_peginManager);
        pegoutManager = IPausable(_pegoutManager);
        committeeRegistry = IPausable(_committeeRegistry);
        memberRegistry = IPausable(_memberRegistry);
        rbtcBridge = IPausable(_rbtcBridge);

        challengeManager = IPausable(_challengeManager);
        __BaseProxy_init(_initialOwner);
    }

    /// @notice Pauses all pausable contracts
    /// @dev Only callable by the contract owner
    function pause() external onlyOwner {
        peginManager.pause();
        pegoutManager.pause();
        committeeRegistry.pause();
        memberRegistry.pause();
        rbtcBridge.pause();
        challengeManager.pause();
    }

    /// @notice Unpauses all pausable contracts
    /// @dev Only callable by the contract owner
    function unpause() external onlyOwner {
        peginManager.unpause();
        pegoutManager.unpause();
        committeeRegistry.unpause();
        memberRegistry.unpause();
        rbtcBridge.unpause();
        challengeManager.unpause();
    }

    /// @notice Returns true if all contracts are paused, false if all are unpaused
    /// @dev Reverts if contracts have inconsistent pause states
    /// @return True if all contracts are paused, false if all are unpaused
    function areContractsPaused() external view returns (bool) {
        bool peginManagerPaused = peginManager.isPaused();
        bool pegoutManagerPaused = pegoutManager.isPaused();
        bool committeeRegistryPaused = committeeRegistry.isPaused();
        bool memberRegistryPaused = memberRegistry.isPaused();
        bool rbtcBridgePaused = rbtcBridge.isPaused();
        bool challengeManagerPaused = challengeManager.isPaused();

        // Check if all contracts have the same pause state
        bool referenceState = peginManagerPaused;
        bool allStatesMatch = pegoutManagerPaused == referenceState && committeeRegistryPaused == referenceState
            && memberRegistryPaused == referenceState && rbtcBridgePaused == referenceState
            && challengeManagerPaused == referenceState;

        if (!allStatesMatch) {
            revert _InconsistentPauseState();
        }

        return referenceState;
    }
}
