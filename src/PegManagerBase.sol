// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PegBase} from "./PegBase.sol";
import {IBitcoinManager} from "./interfaces/IBitcoinManager.sol";
import {IPegManagerBase} from "./interfaces/IPegManagerBase.sol";
import {ICommitteeRegistry} from "./interfaces/ICommitteeRegistry.sol";
import {ISignatureManager} from "./interfaces/ISignatureManager.sol";
import {IRbtcBridge} from "./interfaces/IRbtcBridge.sol";
import {IStreamManager, StreamPosition} from "./interfaces/IStreamManager.sol";

/// @title PegManagerBase
/// @notice Abstract base contract for shared functionality between PeginManager and PegoutManager
/// @dev Contains common state variables, initialization logic, and setter functions
abstract contract PegManagerBase is IPegManagerBase, PegBase {
    /// @notice Signature manager contract for handling multi-signature operations
    ISignatureManager public signatureManager;

    /// @notice Initializes the base PegManager contract
    /// @param _initialOwner The initial owner of the contract
    /// @param _accessManager The access manager contract address
    /// @param _committeeRegistry The committee registry contract address
    /// @param _bitcoinManager The Bitcoin manager contract address
    /// @param _rbtcBridge The RbtcBridge contract for minting/burning RBTC
    /// @param _streamManager The stream manager contract address
    /// @dev This function should be called by child contracts during their initialization
    function __PegManagerBase_init(
        address _initialOwner,
        address _accessManager,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        IRbtcBridge _rbtcBridge,
        IStreamManager _streamManager,
        ISignatureManager _signatureManager
    ) internal onlyInitializing {
        if (address(_signatureManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        signatureManager = _signatureManager;
        __PegBase_init(_initialOwner, _accessManager, _committeeRegistry, _bitcoinManager, _rbtcBridge, _streamManager);
    }

    function _completeSlot(StreamPosition memory _streamInfo, bytes32 _acceptPeginTxid, bytes32 _txid) internal {
        bool packetClosed = streamManager.completeSlot(_acceptPeginTxid, _txid);
        if (packetClosed) {
            committeeRegistry.releaseCommittee(_streamInfo.streamId, _streamInfo.packetNumber);
        }
    }
}
