// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PeginManager} from "src/PeginManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IBitcoinManager} from "src/interfaces/IBitcoinManager.sol";
import {StreamPosition, PegStatus} from "src/interfaces/IPegCommonTypes.sol";

/// @title PeginManagerHarness
/// @notice Test harness for PeginManager to expose internal functions and state for testing
/// @dev TODO: Uncomment and implement harness functions as needed when updating tests
contract PeginManagerHarness is PeginManager {
    function initialize(
        address _initialOwner,
        address payable _bridgeAddress,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager
    ) public override initializer {
        PeginManager.initialize(_initialOwner, _bridgeAddress, _committeeRegistry, _bitcoinManager);
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
