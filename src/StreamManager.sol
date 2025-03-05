// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Stream, Packet, Slot, SlotState, IStreamManager} from "./interfaces/IStreamManager.sol";

/// @title Stream Manager
/// @notice Manages streams
abstract contract StreamManager is IStreamManager, Initializable {
    Stream[] internal streams;
    uint64[] internal denominations;
    uint64 internal constant SECURITY_BOND_MULTIPLYER = 2;
    uint64 public constant MAX_DENOMINATIONS_SIZE = 10;
    uint256[50] private __gap;

    // StreamId => Packet list
    mapping(uint64 => Packet[]) public packets; // TODO see how to handle it in a mapping instead of an array
    // StreamId => Packet.packetNumber => SlotId
    mapping(uint64 => mapping(uint64 => Slot[])) internal slots; // TODO see how to handle it in a mapping instead of an array
    // TODO check if we can use another key or a hash for the slots and packets as they are not unique through the streams

    /// @dev Initializes the streams with their denominations and parameters
    function initialize(uint64[] memory _denominations) internal onlyInitializing {
        uint256 length = _denominations.length;
        if (length > MAX_DENOMINATIONS_SIZE) {
            revert tooManyDenominations(MAX_DENOMINATIONS_SIZE);
        }
        denominations = _denominations;
        for (uint64 i = 0; i < length; i++) {
            streams.push(
                Stream({
                    streamId: i,
                    denomination: _denominations[i],
                    peginPointer: 0,
                    pegoutPointer: -1,
                    securityBondValue: _denominations[i] * SECURITY_BOND_MULTIPLYER,
                    pegInConfirmations: uint8(i + 1)
                })
            );
        }
    }

    /// @dev Creates In all streams a packet and slots using the given committee
    function createPacketsAndSlots(bytes32 _committeePubKey) external {
        uint256 length = denominations.length;
        for (uint64 i = 0; i < length; i++) {
            // Create initial packet
            uint64 packetNumber = uint64(packets[streams[i].streamId].length);
            packets[streams[i].streamId].push(Packet({packetNumber: packetNumber, committeePubKey: _committeePubKey}));

            // Initialize slots directly in storage
            for (uint64 j = 0; j < 100; j++) {
                slots[i][packetNumber].push(
                    Slot({slotId: j, state: SlotState.PREPARED, utxo: "", pegInTx: "", take0Tx: "", take1TX: ""})
                );
            }
        }
    }

    function getStream(uint64 _denomination) public view returns (Stream memory) {
        uint256 length = denominations.length;
        for (uint256 i = 0; i < length; i++) {
            if (streams[i].denomination == _denomination) {
                return streams[i];
            }
        }
        revert StreamNotFoundByDenomination(_denomination);
    }

    function getStreamById(uint64 _streamId) external view returns (Stream memory) {
        return streams[_streamId];
    }

    function getStreamsLength() external view returns (uint64) {
        return uint64(streams.length);
    }

    function getPacket(uint64 _streamId, uint64 _packetNumber) public view returns (Packet memory) {
        Packet[] memory packetList = packets[_streamId];
        if (packetList.length < _packetNumber) {
            revert PacketOutOfBound(_packetNumber);
        }
        return packetList[_packetNumber];
    }

    function getSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) public view returns (Slot memory) {
        return slots[_streamId][_packetNumber][_slotId];
    }

    function getPreparedSlotId(uint64 _streamId, uint64 _packetNumber) public view returns (uint64) {
        Slot[] memory slotList = slots[_streamId][_packetNumber];
        uint256 length = slotList.length;
        for (uint64 i = 0; i < length; i++) {
            if (slotList[i].state == SlotState.PREPARED) {
                return i;
            }
        }
        // If i couldn't find any
        revert NoEmptySlot(_streamId, _packetNumber);
    }

    /// @dev Looks for the first empty slot and asigns the PegIn Tx in prepared state
    function preparePegInTx(uint64 _streamId, uint64 _packetNumber, bytes32 _pegInTx, bytes memory _utxo)
        internal
        returns (uint64)
    {
        uint64 slotId = getPreparedSlotId(_streamId, _packetNumber);
        Slot storage slot = slots[_streamId][_packetNumber][slotId];
        slot.state = SlotState.PREPARED;
        // TODO validate if the PegInTx is what we want to store, as the document mentions the Take for the registerPegInTxs
        // but the takes in the scrut are mentioned to be used by the peg out
        slot.pegInTx = _pegInTx;
        slot.utxo = _utxo;
        return slotId;
    }
}
