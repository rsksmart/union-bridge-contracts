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

    function setSlotHarness(uint64 _streamId, uint64 _packet, bytes memory _scriptPubKey, bytes32 _txId, uint64 _amount)
        external
        returns (uint64)
    {
        if (_packet >= packets[_streamId].length) {
            revert NoPackets(_streamId, _packet);
        }

        return fillSlot(
            _streamId,
            _packet,
            Slot({
                slotId: 0,
                state: SlotState.FILLED,
                scriptPubKey: _scriptPubKey,
                acceptPegInTx: _txId,
                acceptPegInAmount: _amount,
                take0Tx: "",
                take1Tx: ""
            })
        );
    }

    function setPegoutPointers(uint64 _streamId, uint64 _packet, uint16 _slot) external {
        streams[_streamId].pegoutPacketPointer = _packet;
        streams[_streamId].pegoutSlotPointer = _slot;
    }

    function pushSlots(uint64 _streamId, uint64 _packet, uint64 _slotsAmount, SlotState _slotState) external {
        for (uint64 i = 0; i < _slotsAmount; i++) {
            slots[_streamId][_packet].push(
                Slot({
                    slotId: i,
                    state: _slotState,
                    scriptPubKey: hex"00",
                    acceptPegInTx: bytes32(0),
                    acceptPegInAmount: 0,
                    take0Tx: "",
                    take1Tx: ""
                })
            );
        }
    }

    function getSlotsLength(uint64 _streamId, uint64 _packet) external view returns (uint256) {
        return slots[_streamId][_packet].length;
    }

    error NoPackets(uint64 streamId, uint64 packet);
    error NoSlots(uint64 streamId, uint64 packet, uint64 slot);
}
