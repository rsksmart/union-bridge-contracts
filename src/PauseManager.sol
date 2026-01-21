// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BaseProxy} from "./BaseProxy.sol";
import {IPauseManager} from "./interfaces/IPauseManager.sol";
import {IPausable} from "./interfaces/IPausable.sol";

/// @title PauseManager
/// @notice Centralized pause manager for all pausable contracts in the union bridge system
/// @dev This contract is responsible for pausing/unpausing all pausable contracts
abstract contract PauseManager is IPauseManager, BaseProxy {
    /// @notice The PeginManager contract
    address public peginManager;

    /// @notice The PegoutManager contract
    address public pegoutManager;

    /// @notice The CommitteeRegistry contract
    address public committeeRegistry;

    /// @notice The MemberRegistry contract
    address public memberRegistry;

    /// @notice The RbtcBridge contract
    address public rbtcBridge;

    /// @notice The ChallengeManager contract
    address public challengeManager;

    /// @notice Initializes the PauseManager contract
    /// @param _initialOwner The initial owner of the contract who can pause/unpause
    function __PauseManager_init(address _initialOwner) internal initializer {
        __BaseProxy_init(_initialOwner);
    }

    /// @notice Pauses all pausable contracts
    /// @dev Only callable by the contract owner
    function pause() external onlyOwner {
        IPausable(peginManager).pause();
        IPausable(pegoutManager).pause();
        IPausable(committeeRegistry).pause();
        IPausable(memberRegistry).pause();
        IPausable(rbtcBridge).pause();
        IPausable(challengeManager).pause();
    }

    /// @notice Unpauses all pausable contracts
    /// @dev Only callable by the contract owner
    function unpause() external onlyOwner {
        IPausable(peginManager).unpause();
        IPausable(pegoutManager).unpause();
        IPausable(committeeRegistry).unpause();
        IPausable(memberRegistry).unpause();
        IPausable(rbtcBridge).unpause();
        IPausable(challengeManager).unpause();
    }

    /// @notice Returns true if all contracts are paused, false if all are unpaused
    /// @dev Reverts if contracts have inconsistent pause states
    /// @return True if all contracts are paused, false if all are unpaused
    function areContractsPaused() external view returns (bool) {
        bool peginManagerPaused = IPausable(peginManager).isPaused();
        bool pegoutManagerPaused = IPausable(pegoutManager).isPaused();
        bool committeeRegistryPaused = IPausable(committeeRegistry).isPaused();
        bool memberRegistryPaused = IPausable(memberRegistry).isPaused();
        bool rbtcBridgePaused = IPausable(rbtcBridge).isPaused();
        bool challengeManagerPaused = IPausable(challengeManager).isPaused();

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

    /// @notice Sets the committee registry contract address
    /// @dev Can only be called by the owner
    /// @param _committeeRegistry The new committee registry contract address
    function setCommitteeRegistry(address _committeeRegistry) external onlyOwner {
        if (committeeRegistry != address(0)) {
            revert AlreadySet();
        }
        if (address(_committeeRegistry) == address(0)) {
            revert InvalidZeroAddress();
        }
        committeeRegistry = _committeeRegistry;
    }

    /// @notice Sets the pegin manager contract address
    /// @dev Can only be called by the owner
    /// @param _peginManager The new pegin manager contract address
    function setPeginManager(address _peginManager) external onlyOwner {
        if (peginManager != address(0)) {
            revert AlreadySet();
        }
        if (address(_peginManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        peginManager = _peginManager;
    }

    /// @notice Sets the pegout manager contract address
    /// @dev Can only be called by the owner
    /// @param _pegoutManager The new pegout manager contract address
    function setPegoutManager(address _pegoutManager) external onlyOwner {
        if (pegoutManager != address(0)) {
            revert AlreadySet();
        }
        if (address(_pegoutManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        pegoutManager = _pegoutManager;
    }

    /// @notice Sets the challenge manager contract address
    /// @dev Can only be called by the owner
    /// @param _challengeManager The new challenge manager contract address
    function setChallengeManager(address _challengeManager) external onlyOwner {
        if (challengeManager != address(0)) {
            revert AlreadySet();
        }
        if (address(_challengeManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        challengeManager = _challengeManager;
    }

    /// @notice Sets the member registry contract address
    /// @dev Can only be called by the owner
    /// @param _memberRegistry The new member registry contract address
    function setMemberRegistry(address _memberRegistry) external onlyOwner {
        if (memberRegistry != address(0)) {
            revert AlreadySet();
        }
        if (address(_memberRegistry) == address(0)) {
            revert InvalidZeroAddress();
        }
        memberRegistry = _memberRegistry;
    }

    /// @notice Sets the rbtc bridge contract address
    /// @dev Can only be called by the owner
    /// @param _rbtcBridge The new rbtc bridge contract address
    function setRbtcBridge(address _rbtcBridge) external onlyOwner {
        if (rbtcBridge != address(0)) {
            revert AlreadySet();
        }
        if (address(_rbtcBridge) == address(0)) {
            revert InvalidZeroAddress();
        }
        rbtcBridge = _rbtcBridge;
    }
}
