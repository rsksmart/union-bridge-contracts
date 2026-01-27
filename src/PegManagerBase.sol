// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PegBase} from "./PegBase.sol";
import {IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {IPegManagerBase} from "./interfaces/IPegManagerBase.sol";
import {ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {ISignatureManager} from "./interfaces/ISignatureManager.sol";
import {IRbtcBridge} from "./interfaces/IRbtcBridge.sol";
import {IStreamManager} from "./interfaces/IStreamManager.sol";

/// @title PegManagerBase
/// @notice Abstract base contract for shared functionality between PeginManager and PegoutManager
/// @dev Contains common state variables, initialization logic, and setter functions
abstract contract PegManagerBase is IPegManagerBase, PegBase {
    /// @notice Signature manager contract for handling multi-signature operations
    ISignatureManager public signatureManager;

    /// @notice The RbtcBridge contract for minting RBTC
    IRbtcBridge public rbtcBridge;

    /// @notice Initializes the base PegManager contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _bridgeAddress The address of the pow-peg bridge contract
    /// @param _accessManager The access manager contract address
    /// @param _committeeRegistry The committee registry contract address
    /// @param _bitcoinManager The Bitcoin manager contract address
    /// @param _rbtcBridge The RbtcBridge contract address
    /// @param _streamManager The stream manager contract address
    /// @dev This function should be called by child contracts during their initialization
    function __PegManagerBase_init(
        address _initialOwner,
        address payable _bridgeAddress,
        address _accessManager,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        IRbtcBridge _rbtcBridge,
        IStreamManager _streamManager,
        ISignatureManager _signatureManager
    ) internal onlyInitializing {
        // Validate that the addresses are not zero
        if (address(_rbtcBridge) == address(0) || address(_signatureManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        rbtcBridge = _rbtcBridge;
        signatureManager = _signatureManager;

        __PegBase_init(
            _initialOwner, _bridgeAddress, _accessManager, _committeeRegistry, _bitcoinManager, _streamManager
        );
    }
}
