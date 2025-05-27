// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Stream, Packet, Slot, SlotState, IStreamManager} from "./interfaces/IStreamManager.sol";
import {AccessControl} from "./AccessControl.sol";
import {Constants} from "src/libraries/Constants.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";

/// @title Stream Manager
/// @notice Manages streams
contract StreamManager is IStreamManager, AccessControl {
    uint64 public constant MAX_DENOMINATIONS_SIZE = 10;
    Stream[] internal streams;

    // StreamId => Packet list
    mapping(uint64 => Packet[]) public packets;
    // StreamId => Packet.packetNumber => SlotId
    mapping(uint64 => mapping(uint64 => Slot[])) internal slots;
    // TODO check if we can use another key or a hash for the slots and packets as they are not unique through the streams

    /// @dev Initializes the streams with their denominations and parameters
    function initialize(address _initialOwner, address _pegManager, uint64[] memory _denominations)
        public
        virtual
        initializer
    {
        uint256 length = _denominations.length;
        if (length > MAX_DENOMINATIONS_SIZE) {
            revert tooManyDenominations(MAX_DENOMINATIONS_SIZE);
        }
        for (uint64 i = 0; i < length; i++) {
            streams.push(
                Stream({
                    streamId: i,
                    denomination: _denominations[i],
                    peginPacketPointer: 0,
                    pegoutPacketPointer: 0,
                    pegoutSlotPointer: 0,
                    securityBondValue: BtcHelper.satoshiToWei(_denominations[i]) / 10,
                    peginConfirmations: Constants.PEGIN_CONFIRMATION_DEFAULT
                })
            );
            emit StreamCreated(i, _denominations[i]);
        }
        __AccessControl_init(_initialOwner, _pegManager);
    }

    /// @dev Adds one packet per stream
    // FIXME: This is a temporary function to create initial packets and should be removed soon
    function createInitialPackets(bytes32 _committeePubKey) external onlyOwner {
        uint256 length = streams.length;
        for (uint256 i = 0; i < length; i++) {
            uint64 streamId = streams[i].streamId;
            if (packets[streamId].length > 0) {
                revert StreamAlreadyInitialized(streamId);
            }
            // FIXME: Force packets to be assigned to committeeId 1
            uint256 committeeId = 1;
            // Add a new packet for each stream
            _createNewPacket(streamId, committeeId, _committeePubKey);
        }
    }

    // FIXME: This should be called just from CommitteeRegistry
    function createNewPacket(uint64 _streamId, uint256 _committeeId, bytes32 _committeePubKey) external {
        _createNewPacket(_streamId, _committeeId, _committeePubKey);
    }

    function _createNewPacket(uint64 _streamId, uint256 _committeeId, bytes32 _committeePubKey) internal {
        uint64 packetNumber = uint64(packets[_streamId].length);
        packets[_streamId].push(
            Packet({packetNumber: packetNumber, committeeId: _committeeId, committeePubKey: _committeePubKey})
        );
        emit PacketCreated(_streamId, packetNumber);
    }

    function getStream(uint64 _denomination) external view returns (Stream memory) {
        uint256 length = streams.length;
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

    function getPacketsLength(uint64 _streamId) external view returns (uint64) {
        return uint64(packets[_streamId].length);
    }

    function getPacket(uint64 _streamId, uint64 _packetNumber) public view returns (Packet memory) {
        if (streams.length <= _streamId) {
            revert StreamNotFoundById(_streamId);
        }

        if (packets[_streamId].length <= _packetNumber) {
            revert PacketOutOfBound(_packetNumber);
        }
        return packets[_streamId][_packetNumber];
    }

    function fillSlot(uint64 _streamId, uint64 _packetNumber, Slot memory slot) internal returns (uint64 slotId) {
        Stream storage stream = streams[_streamId];

        // Force state to FILLED;
        slot.state = SlotState.FILLED;

        // If packet does not match with current packet being processed
        if (_packetNumber != stream.peginPacketPointer) {
            revert InvalidPeginPacketNumber(_streamId, _packetNumber);
        }

        slotId = uint64(slots[_streamId][_packetNumber].length);
        slot.slotId = slotId;
        slots[_streamId][_packetNumber].push(slot);
        emit SlotCreated(_streamId, _packetNumber, slotId);

        if (slots[_streamId][_packetNumber].length > Constants.SLOTS_PER_PACKET) {
            revert InconsistentSlotsPerPacket(_streamId, _packetNumber, slots[_streamId][_packetNumber].length);
        }

        // Update the stream pegIn pointer
        if (slots[_streamId][_packetNumber].length == Constants.SLOTS_PER_PACKET) {
            // NOTE: Check max amount of packets and/or overflow
            stream.peginPacketPointer++;
        }

        return slotId;
    }

    /// @dev Returns the first filled slot, lock it and updates the pegout pointers
    function lockSlot(uint64 _streamId) external onlyPegManager returns (Slot memory, uint64 packetNumber) {
        uint256 packetCount = packets[_streamId].length;
        // No packets created yet
        if (packetCount == 0) {
            revert PacketNotFound(_streamId, 0);
        }

        Stream storage stream = streams[_streamId];
        // Save packet number to return
        packetNumber = stream.pegoutPacketPointer;

        // No new packets created since last pegout
        if (packetNumber >= packetCount) {
            revert PacketNotFound(_streamId, packetNumber);
        }

        // All slots are pegged out.
        if (stream.pegoutSlotPointer >= slots[_streamId][packetNumber].length) {
            revert NonExistentSlot(_streamId, packetNumber, stream.pegoutSlotPointer);
        }

        Slot storage slot = slots[_streamId][packetNumber][stream.pegoutSlotPointer];
        if (slot.state != SlotState.FILLED) {
            revert NoFilledSlot(_streamId, packetNumber, stream.pegoutSlotPointer);
        }

        // If the slot is filled, we return it
        slot.state = SlotState.LOCKED;

        // Update the stream pegout pointers
        stream.pegoutSlotPointer++;
        if (stream.pegoutSlotPointer > Constants.SLOTS_PER_PACKET) {
            revert InconsistentPegoutPointer(_streamId, packetNumber, stream.pegoutSlotPointer);
        }

        if (stream.pegoutSlotPointer == Constants.SLOTS_PER_PACKET) {
            stream.pegoutPacketPointer++;
            stream.pegoutSlotPointer = 0;
        }

        return (slot, packetNumber);
    }

    function getSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotNumber) external view returns (Slot memory) {
        if (_packetNumber >= packets[_streamId].length) {
            revert NonExistentSlot(_streamId, _packetNumber, _slotNumber);
        }
        if (_slotNumber >= slots[_streamId][_packetNumber].length) {
            revert NonExistentSlot(_streamId, _packetNumber, _slotNumber);
        }
        return slots[_streamId][_packetNumber][_slotNumber];
    }

    /// @dev Looks for the first empty slot and asigns the PegIn Tx in prepared state
    function fillAcceptPegInTx(
        uint64 _streamId,
        uint64 _packetNumber,
        uint64 _acceptPegInAmount,
        bytes32 _acceptPegInTx,
        bytes memory _scriptPubKey
    ) external onlyPegManager returns (uint64) {
        return fillSlot(
            _streamId,
            _packetNumber,
            Slot({
                slotId: 0,
                state: SlotState.FILLED,
                acceptPegInTx: _acceptPegInTx,
                acceptPegInAmount: _acceptPegInAmount,
                scriptPubKey: _scriptPubKey,
                take0Tx: "",
                take1Tx: ""
            })
        );
    }

    function getCommitteeId(uint64 _streamId, uint64 _packetNumber) external view returns (uint256) {
        return getPacket(_streamId, _packetNumber).committeeId;
    }

    function getCommitteePubKey(uint64 _streamId, uint64 _packetNumber) external view returns (bytes32) {
        return getPacket(_streamId, _packetNumber).committeePubKey;
    }

    function setSecurityBond(uint64 _streamId, uint256 _securityBondValue) external streamExists(_streamId) onlyOwner {
        if (_securityBondValue == 0) {
            revert InvalidSecurityBondValue(_securityBondValue);
        }

        streams[_streamId].securityBondValue = _securityBondValue;
    }

    function setPeginConfirmations(uint64 _streamId, uint8 _confirmations) external streamExists(_streamId) onlyOwner {
        if (_confirmations == 0) {
            revert InvalidPeginConfirmations(_confirmations);
        }

        streams[_streamId].peginConfirmations = _confirmations;
    }

    modifier streamExists(uint64 _streamId) {
        if (_streamId >= streams.length) {
            revert StreamNotFoundById(_streamId);
        }
        _;
    }
}
