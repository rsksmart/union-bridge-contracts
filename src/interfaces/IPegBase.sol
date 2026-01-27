// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {IStreamManager} from "./IStreamManager.sol";
import {PegStatus} from "./IPegCommonTypes.sol";
import {IPausable} from "./IPausable.sol";

/// @title IPegBase
/// @notice Interface for the base contract for PeginManager, PegoutManager and ChallengeManager
interface IPegBase is IPausable {
    /// @notice Emitted when the stream manager is updated
    /// @param _streamManager The new stream manager address
    event StreamManagerUpdated(IStreamManager _streamManager);

    // ===================== Errors =====================

    /// @notice Thrown when trying to process a peg-out for a peg-in that hasn't been requested
    /// @param btcTxid The Bitcoin transaction id that wasn't requested
    error PeginNotRequested(bytes32 btcTxid);

    /// @notice Thrown when the peg status is not valid for the current operation
    /// @param actual The actual peg status that was found
    error InvalidPegStatus(PegStatus actual);
}
