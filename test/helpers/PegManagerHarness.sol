// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IBitcoinManager} from "src/interfaces/IBitcoinManager.sol";
import {BtcTaproot} from "src/libraries/BtcTaproot.sol";
import {SlotState, Slot} from "src/interfaces/IStreamManager.sol";
import {PegManager} from "src/PegManager.sol";
import "forge-std/console.sol";

/// @notice Wrapper for testing PegManager
contract PegManagerHarness is PegManager {
    function initialize(
        address _initialOwner,
        address payable _bridgeAddress,
        ICommitteeRegistry _committeeRegistry,
        IBitcoinManager _bitcoinManager,
        uint64[] memory _denominations
    ) public override initializer {
        PegManager.initialize(_initialOwner, _bridgeAddress, _committeeRegistry, _bitcoinManager, _denominations);
    }

    function setSlotHarness(
        uint64 _streamId,
        uint64 _packet,
        uint64 _slot,
        SlotState slotState,
        bytes memory scriptPubKey,
        bytes32 txId
    ) external {
        if (_packet >= packets[_streamId].length) {
            console.log("No packets %d for streamId: %d", _packet, _streamId);
        }
        if (_slot >= slots[_streamId][0].length) {
            console.log("No slot %d in packet %d for streamId: %d", _slot, _packet, _streamId);
        }
        Slot storage slot = slots[_streamId][_packet][_slot];
        slot.state = slotState;
        slot.scriptPubKey = scriptPubKey;
        slot.acceptPegInTx = txId;
    }
}
