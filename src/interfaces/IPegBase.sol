// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {IStreamManager} from "./IStreamManager.sol";
import {IBitcoinManager} from "./IBitcoinManager.sol";
import {ICommitteeRegistry} from "./ICommitteeRegistry.sol";
import {PegStatus} from "./IPegCommonTypes.sol";

/// @title IPegManagerBase
/// @notice Interface for shared functionality between PeginManager and PegoutManager
interface IPegBase {
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

    /// @notice Error thrown when bitcoin manager address is zero
    error BitcoinManagerAddressZero();

    /// @notice Error thrown when committee registry address is zero
    error CommitteeRegistryAddressZero();

    /// @notice Error thrown when stream manager address is zero
    error StreamManagerAddressZero();

    // ===================== External Functions =====================

    /// @notice Returns the bitcoin manager contract
    /// @return The bitcoin manager contract
    function bitcoinManager() external view returns (IBitcoinManager);

    /// @notice Returns the stream manager contract
    /// @return The stream manager contract
    function streamManager() external view returns (IStreamManager);

    /// @notice Returns the committee registry contract
    /// @return The committee registry contract
    function committeeRegistry() external view returns (ICommitteeRegistry);

    /// @notice Sets the stream manager contract address
    /// @param _streamManager The stream manager contract address
    function setStreamManager(IStreamManager _streamManager) external;
}
