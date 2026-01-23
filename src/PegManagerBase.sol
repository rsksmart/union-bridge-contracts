// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PegBase} from "./PegBase.sol";
import {IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {IPegManagerBase} from "./interfaces/IPegManagerBase.sol";
import {ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {ISignatureManager} from "./interfaces/ISignatureManager.sol";
import {IRbtcBridge} from "./interfaces/IRbtcBridge.sol";

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
    /// @param _committeeRegistry The committee registry contract address
    /// @param _bitcoinManager The Bitcoin manager contract address
    /// @param _rbtcBridge The RbtcBridge contract address
    /// @dev This function should be called by child contracts during their initialization
    function __PegManagerBase_init(
        address _initialOwner,
        address payable _bridgeAddress,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        IRbtcBridge _rbtcBridge
    ) internal onlyInitializing {
        if (address(_rbtcBridge) == address(0)) {
            revert RbtcBridgeAddressZero();
        }
        rbtcBridge = _rbtcBridge;

        __PegBase_init(_initialOwner, _bridgeAddress, _committeeRegistry, _bitcoinManager);
    }

    /// @notice Sets the signature manager contract address
    /// @param _signatureManager The signature manager contract address
    /// @dev Only callable by the contract owner
    function setSignatureManager(ISignatureManager _signatureManager) external onlyOwner {
        if (address(_signatureManager) == address(0)) {
            revert SignatureManagerAddressZero();
        }
        signatureManager = _signatureManager;
        emit SignatureManagerUpdated(_signatureManager);
    }
}
