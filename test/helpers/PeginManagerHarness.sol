// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PeginManager} from "src/PeginManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IBitcoinManager} from "src/interfaces/IBitcoinManager.sol";
import {StreamPosition, PegStatus} from "src/interfaces/IPegCommonTypes.sol";
import {IRbtcBridge} from "src/interfaces/IRbtcBridge.sol";
import {IStreamManager} from "src/interfaces/IStreamManager.sol";
import {ISignatureManager} from "src/interfaces/ISignatureManager.sol";

/// @title PeginManagerHarness
/// @notice Test harness for PeginManager to expose internal functions and state for testing
contract PeginManagerHarness is PeginManager {
    function initialize(
        address _initialOwner,
        address payable _bridgeAddress,
        address _accessManager,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        IRbtcBridge _rbtcBridge,
        IStreamManager _streamManager,
        ISignatureManager _signatureManager
    ) public override initializer {
        PeginManager.initialize(
            _initialOwner,
            _bridgeAddress,
            _accessManager,
            _committeeRegistry,
            _bitcoinManager,
            _rbtcBridge,
            _streamManager,
            _signatureManager
        );
    }

    function setStreamPositionHarness(
        bytes32 _acceptPeginTxid,
        uint64 _streamId,
        uint64 _packetNumber,
        uint64 _slotId,
        PegStatus _pegStatus
    ) external {
        streamManager.setStreamPosition(
            _acceptPeginTxid,
            StreamPosition({streamId: _streamId, packetNumber: _packetNumber, slotId: _slotId, pegStatus: _pegStatus})
        );
    }
}
