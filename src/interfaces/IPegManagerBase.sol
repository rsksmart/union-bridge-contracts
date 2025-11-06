// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {IStreamManager} from "./IStreamManager.sol";
import {ISignatureManager} from "./ISignatureManager.sol";
import {IBitcoinManager} from "./IBitcoinManager.sol";
import {ICommitteeRegistry} from "./ICommitteeRegistry.sol";

/// @title IPegManagerBase
/// @notice Interface for shared functionality between PeginManager and PegoutManager
interface IPegManagerBase {
    /// @notice Emitted when the stream manager is updated
    /// @param _streamManager The new stream manager address
    event StreamManagerUpdated(IStreamManager _streamManager);

    /// @notice Emitted when the signature manager is updated
    /// @param _signatureManager The new signature manager address
    event SignatureManagerUpdated(ISignatureManager _signatureManager);

    /// @notice Error thrown when bitcoin manager address is zero
    error BitcoinManagerAddressZero();

    /// @notice Error thrown when committee registry address is zero
    error CommitteeRegistryAddressZero();

    /// @notice Error thrown when signature manager address is zero
    error SignatureManagerAddressZero();

    /// @notice Error thrown when stream manager address is zero
    error StreamManagerAddressZero();

    /// @notice Returns the bitcoin manager contract
    /// @return The bitcoin manager contract
    function bitcoinManager() external view returns (IBitcoinManager);

    /// @notice Returns the stream manager contract
    /// @return The stream manager contract
    function streamManager() external view returns (IStreamManager);

    /// @notice Returns the committee registry contract
    /// @return The committee registry contract
    function committeeRegistry() external view returns (ICommitteeRegistry);

    /// @notice Returns the signature manager contract
    /// @return The signature manager contract
    function signatureManager() external view returns (ISignatureManager);

    /// @notice Sets the stream manager contract address
    /// @param _streamManager The stream manager contract address
    function setStreamManager(IStreamManager _streamManager) external;

    /// @notice Sets the signature manager contract address
    /// @param _signatureManager The signature manager contract address
    function setSignatureManager(ISignatureManager _signatureManager) external;
}
