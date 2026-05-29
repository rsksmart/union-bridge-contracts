// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPegBase} from "./IPegBase.sol";
import {ISignatureManager} from "./ISignatureManager.sol";

/// @title IPegManagerBase
/// @notice Interface for shared functionality between PeginManager and PegoutManager
interface IPegManagerBase is IPegBase {
    /// @notice Emitted when the signature manager is updated
    /// @param _signatureManager The new signature manager address
    event SignatureManagerUpdated(ISignatureManager _signatureManager);
}
