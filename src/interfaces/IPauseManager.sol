// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

/// @title IPauseManager
/// @notice Interface for the centralized pause manager contract
/// @dev This contract is responsible for pausing/unpausing all pausable contracts in the system
interface IPauseManager {
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
    ) external;

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

    /// @notice Emitted when a pausable contract address is updated
    /// @param contractName The name of the contract that was updated
    /// @param newAddress The new address of the contract
    event PausableContractUpdated(string contractName, address newAddress);

    /// @notice Error thrown when a zero address is provided
    error ZeroAddress();

    /// @notice Error thrown when the pause states of contracts are inconsistent
    /// @dev This error is thrown when not all pausable contracts have the same pause state
    error _InconsistentPauseState();
}
