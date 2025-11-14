// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

/// @notice Interface for pauser in the union bridge
/// @dev This interface provides error definitions for pauser operations
/// @dev Used to implement open zeppelin's pauser functionality
interface IPausable {
    /// @notice External functions to handle pauser pauses
    function pause() external;
    function unpause() external;
    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function isPaused() external view returns (bool);
}
