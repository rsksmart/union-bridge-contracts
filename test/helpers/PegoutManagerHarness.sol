// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {PegoutManager} from "src/PegoutManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IBitcoinManager} from "src/interfaces/IBitcoinManager.sol";
import {IRbtcBridge} from "src/interfaces/IRbtcBridge.sol";
import {IStreamManager} from "src/interfaces/IStreamManager.sol";
import {ISignatureManager} from "src/interfaces/ISignatureManager.sol";
import {PegoutRequest} from "src/interfaces/IPegoutManager.sol";

/// @title PegoutManagerHarness
/// @notice Test harness for PegoutManager to expose internal functions and state for testing
contract PegoutManagerHarness is PegoutManager {
    function initialize(
        address _initialOwner,
        address _accessManager,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        IRbtcBridge _rbtcBridge,
        IStreamManager _streamManager,
        ISignatureManager _signatureManager
    ) public override initializer {
        PegoutManager.initialize(
            _initialOwner,
            _accessManager,
            _committeeRegistry,
            _bitcoinManager,
            _rbtcBridge,
            _streamManager,
            _signatureManager
        );
    }

    function getPegoutQueueHarness(uint64 _streamId) external view returns (PegoutRequest[] memory queue) {
        uint64 queueLength = _getPegoutQueueLength(_streamId);
        queue = new PegoutRequest[](queueLength);
        uint64 startPointer = currentPegoutQueuePointer[_streamId];
        for (uint64 i = 0; i < queueLength; i++) {
            queue[i] = pegoutQueue[_streamId][startPointer + i];
        }
    }
}
