// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {IPegBase} from "./IPegBase.sol";
import {ISignatureManager} from "./ISignatureManager.sol";
import {IRbtcBridge} from "./IRbtcBridge.sol";

/// @title IPegManagerBase
/// @notice Interface for shared functionality between PeginManager and PegoutManager
interface IPegManagerBase is IPegBase {
    /// @notice Emitted when the signature manager is updated
    /// @param _signatureManager The new signature manager address
    event SignatureManagerUpdated(ISignatureManager _signatureManager);

    // ===================== Errors =====================

    /// @notice Error thrown when signature manager address is zero
    error SignatureManagerAddressZero();

    /// @notice Error thrown when RbtcBridge address is zero
    error RbtcBridgeAddressZero();

    // ===================== External Functions =====================

    /// @notice Sets the signature manager contract address
    /// @param _signatureManager The signature manager contract address
    function setSignatureManager(ISignatureManager _signatureManager) external;
}
