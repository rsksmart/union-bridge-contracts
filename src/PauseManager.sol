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

    /// @notice The OperatorTakeManager contract
    address public operatorTakeManager;

    /// @notice Initializes the PauseManager contract
    /// @param _initialOwner The initial owner of the contract who can pause/unpause
    function __PauseManager_init(address _initialOwner) internal initializer {
        __BaseProxy_init(_initialOwner);
    }

    /// @inheritdoc IPauseManager
    function pause() external onlyOwner {
        IPausable(peginManager).pause();
        IPausable(pegoutManager).pause();
        IPausable(committeeRegistry).pause();
        IPausable(memberRegistry).pause();
        IPausable(rbtcBridge).pause();
        IPausable(challengeManager).pause();
        IPausable(operatorTakeManager).pause();
    }

    /// @inheritdoc IPauseManager
    function unpause() external onlyOwner {
        IPausable(peginManager).unpause();
        IPausable(pegoutManager).unpause();
        IPausable(committeeRegistry).unpause();
        IPausable(memberRegistry).unpause();
        IPausable(rbtcBridge).unpause();
        IPausable(challengeManager).unpause();
        IPausable(operatorTakeManager).unpause();
    }

    /// @inheritdoc IPauseManager
    function areContractsPaused() external view returns (bool) {
        bool peginManagerPaused = IPausable(peginManager).isPaused();
        bool pegoutManagerPaused = IPausable(pegoutManager).isPaused();
        bool committeeRegistryPaused = IPausable(committeeRegistry).isPaused();
        bool memberRegistryPaused = IPausable(memberRegistry).isPaused();
        bool rbtcBridgePaused = IPausable(rbtcBridge).isPaused();
        bool challengeManagerPaused = IPausable(challengeManager).isPaused();
        bool operatorTakeManagerPaused = IPausable(operatorTakeManager).isPaused();

        // Check if all contracts have the same pause state
        bool referenceState = peginManagerPaused;
        bool allStatesMatch = pegoutManagerPaused == referenceState && committeeRegistryPaused == referenceState
            && memberRegistryPaused == referenceState && rbtcBridgePaused == referenceState
            && challengeManagerPaused == referenceState && operatorTakeManagerPaused == referenceState;

        if (!allStatesMatch) {
            revert _InconsistentPauseState();
        }

        return referenceState;
    }

    /// @inheritdoc IPauseManager
    function setCommitteeRegistry(address _committeeRegistry) external onlyOwner {
        if (committeeRegistry != address(0)) {
            revert AlreadySet();
        }
        if (_committeeRegistry == address(0)) {
            revert InvalidZeroAddress();
        }
        committeeRegistry = _committeeRegistry;
    }

    /// @inheritdoc IPauseManager
    function setPeginManager(address _peginManager) external onlyOwner {
        if (peginManager != address(0)) {
            revert AlreadySet();
        }
        if (_peginManager == address(0)) {
            revert InvalidZeroAddress();
        }
        peginManager = _peginManager;
    }

    /// @inheritdoc IPauseManager
    function setPegoutManager(address _pegoutManager) external onlyOwner {
        if (pegoutManager != address(0)) {
            revert AlreadySet();
        }
        if (_pegoutManager == address(0)) {
            revert InvalidZeroAddress();
        }
        pegoutManager = _pegoutManager;
    }

    /// @inheritdoc IPauseManager
    function setChallengeManager(address _challengeManager) external onlyOwner {
        if (challengeManager != address(0)) {
            revert AlreadySet();
        }
        if (_challengeManager == address(0)) {
            revert InvalidZeroAddress();
        }
        challengeManager = _challengeManager;
    }

    /// @notice Sets the OperatorTakeManager contract address
    /// @param _operatorTakeManager The address of the OperatorTakeManager contract
    function setOperatorTakeManager(address _operatorTakeManager) external onlyOwner {
        if (operatorTakeManager != address(0)) {
            revert AlreadySet();
        }
        if (_operatorTakeManager == address(0)) {
            revert InvalidZeroAddress();
        }
        operatorTakeManager = _operatorTakeManager;
    }

    /// @inheritdoc IPauseManager
    function setMemberRegistry(address _memberRegistry) external onlyOwner {
        if (memberRegistry != address(0)) {
            revert AlreadySet();
        }
        if (_memberRegistry == address(0)) {
            revert InvalidZeroAddress();
        }
        memberRegistry = _memberRegistry;
    }

    /// @inheritdoc IPauseManager
    function setRbtcBridge(address _rbtcBridge) external onlyOwner {
        if (rbtcBridge != address(0)) {
            revert AlreadySet();
        }
        if (_rbtcBridge == address(0)) {
            revert InvalidZeroAddress();
        }
        rbtcBridge = _rbtcBridge;
    }
}
