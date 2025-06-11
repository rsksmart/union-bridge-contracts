// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SlotState, Slot, StreamManager} from "src/StreamManager.sol";
import {ICommitteeRegistry} from "src/interfaces/ICommitteeRegistry.sol";
import {IPegManager} from "src/interfaces/IPegManager.sol";

/// @notice Wrapper for testing StreamManager
contract StreamManagerHarness is StreamManager {
    function initialize(
        address _initialOwner,
        IPegManager _pegManager,
        ICommitteeRegistry _committeeRegistry,
        uint64[] memory _denominations
    ) public override initializer {
        StreamManager.initialize(_initialOwner, _pegManager, _committeeRegistry, _denominations);
    }

    function setSlotHarness(uint64 _streamId, uint64 _packet, bytes memory _scriptPubKey, bytes32 _txId, uint64 _amount)
        external
        returns (uint64)
    {
        if (_packet >= packets[_streamId].length) {
            revert NoPacketsHarness(_streamId, _packet);
        }

        return fillSlot(
            _streamId,
            _packet,
            Slot({
                slotId: 0,
                state: SlotState.FILLED,
                scriptPubKey: _scriptPubKey,
                acceptPeginTx: _txId,
                acceptPeginAmount: _amount,
                take0Tx: "",
                take1Tx: ""
            })
        );
    }

    function setPegoutPointersHarness(uint64 _streamId, uint64 _packet, uint16 _slot) external {
        streams[_streamId].pegoutPacketPointer = _packet;
        streams[_streamId].pegoutSlotPointer = _slot;
    }

    function pushSlotsHarness(uint64 _streamId, uint64 _packet, uint64 _slotsAmount, SlotState _slotState) external {
        for (uint64 i = 0; i < _slotsAmount; i++) {
            slots[_streamId][_packet].push(
                Slot({
                    slotId: i,
                    state: _slotState,
                    scriptPubKey: hex"00",
                    acceptPeginTx: bytes32(0),
                    acceptPeginAmount: 0,
                    take0Tx: "",
                    take1Tx: ""
                })
            );
        }
    }

    function getSlotsLengthHarness(uint64 _streamId, uint64 _packet) external view returns (uint256) {
        return slots[_streamId][_packet].length;
    }

    function setSlotStateHarness(uint64 _streamId, uint64 _packet, uint64 _slotId, SlotState _state) external {
        if (_packet >= packets[_streamId].length) {
            revert NoPacketsHarness(_streamId, _packet);
        }
        if (_slotId >= slots[_streamId][_packet].length) {
            revert NoSlotsHarness(_streamId, _packet, _slotId);
        }
        slots[_streamId][_packet][_slotId].state = _state;
    }

    error NoSlotsHarness(uint64 streamId, uint64 packet, uint64 slot);
    error NoPacketsHarness(uint64 streamId, uint64 packet);
}
