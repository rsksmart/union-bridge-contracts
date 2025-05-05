// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SlotState, Slot, StreamManager} from "src/StreamManager.sol";

/// @notice Wrapper for testing StreamManager
contract StreamManagerHarness is StreamManager {
    function initialize(address _initialOwner, address _pegManager, uint64[] memory _denominations)
        public
        override
        initializer
    {
        StreamManager.initialize(_initialOwner, _pegManager, _denominations);
    }

    function setSlotHarness(
        uint64 _streamId,
        uint64 _packet,
        uint64 _slot,
        SlotState _slotState,
        bytes memory _scriptPubKey,
        bytes32 _txId,
        uint64 _amount
    ) external {
        if (_packet >= packets[_streamId].length) {
            revert NoPackets(_streamId, _packet);
        }
        if (_slot >= slots[_streamId][0].length) {
            revert NoSlots(_streamId, _packet, _slot);
        }
        Slot storage slot = slots[_streamId][_packet][_slot];
        slot.state = _slotState;
        slot.scriptPubKey = _scriptPubKey;
        slot.acceptPegInTx = _txId;
        slot.acceptPegInAmount = _amount;
    }

    error NoPackets(uint64 streamId, uint64 packet);
    error NoSlots(uint64 streamId, uint64 packet, uint64 slot);
}
