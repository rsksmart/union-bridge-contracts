// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

/// @title IPauseManager
/// @notice Interface for the centralized pause manager contract
/// @dev This contract is responsible for pausing/unpausing all pausable contracts in the system
interface IPauseManager {
    /// @notice Pauses all pausable contracts
    /// @dev Only callable by the contract owner
    function pause() external;

    /// @notice Unpauses all pausable contracts
    /// @dev Only callable by the contract owner
    function unpause() external;

    /// @notice Returns true if all contracts are paused, false if all are unpaused
    /// @dev Reverts if contracts have inconsistent pause states
    /// @return True if all contracts are paused, false if all are unpaused
    function areContractsPaused() external view returns (bool);

    // ===================== Setters =====================

    /// @notice Sets the Committee Registry contract address
    /// @dev Only callable by the contract owner
    /// @param _committeeRegistry The address of the Committee Registry contract
    function setCommitteeRegistry(address _committeeRegistry) external;

    /// @notice Sets the Pegin Manager contract address
    /// @dev Only callable by the contract owner
    /// @param _peginManager The address of the Pegin Manager contract
    function setPeginManager(address _peginManager) external;

    /// @notice Sets the Pegout Manager contract address
    /// @dev Only callable by the contract owner
    /// @param _pegoutManager The address of the Pegout Manager contract
    function setPegoutManager(address _pegoutManager) external;

    /// @notice Sets the Pegout Manager contract address
    /// @dev Only callable by the contract owner
    /// @param _challengeManager The address of the Challenge Manager contract
    function setChallengeManager(address _challengeManager) external;

    /// @notice Sets the member registry contract address
    /// @dev Only callable by the contract owner
    /// @param _memberRegistry The address of the Member Registry contract
    function setMemberRegistry(address _memberRegistry) external;

    /// @notice Sets the rbtc bridge contract address
    /// @dev Only callable by the contract owner
    /// @param _rbtcBridge The address of the Rbtc Bridge contract
    function setRbtcBridge(address _rbtcBridge) external;

    // ===================== Events =====================

    /// @notice Emitted when a pausable contract address is updated
    /// @param contractName The name of the contract that was updated
    /// @param newAddress The new address of the contract
    event PausableContractUpdated(string contractName, address newAddress);

    // ===================== Errors =====================

    /// @notice Error thrown when the pause states of contracts are inconsistent
    /// @dev This error is thrown when not all pausable contracts have the same pause state
    error _InconsistentPauseState();

    /// @notice Thrown when the value is zero
    error InvalidZeroAddress();

    /// @notice Thrown when the value is already set to a non-zero address
    error AlreadySet();
}
